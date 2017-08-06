class GraphQL
  class QueryParser
    def initialize(tokens)
      @tokens = tokens
      @current = 0
    end

    def execute
      program = []

      while(@current < @tokens.length) do
        program.push(parse())
      end

      require 'pry'; binding.pry

      program.flatten
    end

    private

    def parse
      token = @tokens[@current]

      if token[:type] == 'str'
        @current += 1
        return { token[:value] => { "_@params" => nil } }
      end

      if token[:type] == 'paren'
        @current += 1
        prog = {}

        while(token[:type] != 'paren' || (token[:type] == 'paren' && token[:value] != ')'))
          token = @tokens[@current]

          if @tokens[@current + 1][:type] == 'equalTo'
            prog[token[:value]] = @tokens[@current + 2][:value]
          end

          token = @tokens[@current]
          @current += 3
          token = @tokens[@current]
        end

        @current += 1

        return { '_@params' => prog }
      end

      if token[:type] == 'b'
        @current += 1
        prog = []

        while(token[:type] != 'b' || (token[:type] == 'b' && token[:value] != '}'))
          newVal = parse()

          if newVal.is_a?(Hash) && newVal.key?('_@params')
            prog.last[prog.last.keys.last].merge! newVal
          else
            prog.push(newVal)
          end

          token = @tokens[@current]
        end

        @current += 1

        prog
      end
    end
  end

  class QueryTokenizer
    def initialize(query_as_string)
      @query = query_as_string
    end

    def execute
      current = 0
      tokens = []

      while (current < @query.length) do
        char = @query[current]

        if char == '{'
          tokens.push({
            type: 'b',
            value: char
          })

          current += 1
        end

        if char == '}'
          tokens.push({
            type: 'b',
            value: char
          })

          current += 1
        end

        if char == '('
          tokens.push({
            type: 'paren',
            value: char
          })

          current += 1
        end

        if char == ')'
          tokens.push({
            type: 'paren',
            value: char
          })

          current += 1
        end

        if char == ':'
          tokens.push({
            type: 'equalTo',
            value: char
          })

          current += 1
        end

        if char =~ /\s/
          current += 1
        end

        if char =~ /[a-z]/i
          value = ''

          while(char =~ /[a-z]/i) do
            value += char
            char = @query[current += 1]
          end

          tokens.push({
            type: 'str',
            value: value
          })
        end

        if char =~ /[0-9]/
          value = ''

          while(char =~ /[0-9]/) do
            value += char
            char = @query[current += 1]
          end

          tokens.push({
            type: 'num',
            value: value
          })
        end
      end

      tokens
    end
  end

  class QueryTransformer
    def initialize(query_as_string)
      @query = query_as_string
    end

    def execute
      tokens = QueryTokenizer.new(@query).execute
      parsed = QueryParser.new(tokens).execute
      Query.new(parsed)
    end
  end

  class Query
    def initialize(parsed_query)
      @parsed_query = parsed_query
    end

    def each
      @parsed_query.each do |key|
        yield key
      end
    end
  end

  class Schema
    def initialize(data)
      @data = data
    end

    def [](k)
      if @data.key?(k)
        @data[k]
      else
        raise ArgumentError, "'#{k}' is not in the schema!"
      end
    end
  end

  def initialize(schema_as_hash)
    @schema = Schema.new(schema_as_hash)
  end

  def execute(query, context: {})
    result = {}

    transform(query).each do |subqueries|
      subqueries.each do |attr, nested_attrs|
        result[attr] = @schema[attr]['resolve'].call(nested_attrs["_@params"], context)
      end
    end

    { data: result }
  end

  private

  def transform(query)
    QueryTransformer.new(query).execute
  end
end


###

#parse_walk = lambda do
        #token = tokens[current]

        #if token[:type] == 'str'
          #current += 1
          #return { token[:value] => nil }
        #end

        #if token[:type] == 'lb'
          #token = tokens[current += 1]
          #token = tokens[current += 1]

          #while(token[:type] != 'rb') do
            #query_as_hash.merge! parse_walk.call
          #end

          #current += 1

          #return query_as_hash
        #end
      #end

      ####

      #while (current < tokens.length) do
        #parse_walk.call
      #end
