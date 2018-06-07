class GraphQL
  class QueryParser
    def initialize(tokens)
      @tokens = tokens
      @current = 0
    end

    def execute
      # test_basic_query
      # test_context_received
      [
        QueryField.new('hello')
      ]

      # test_type_not_in_schema_query
      #[
        #QueryField.new('goodbye')
      #]

      # test_two_root_types_query
      #[
        #QueryField.new('hello'),
        #QueryField.new('hello')
      #]

      # test_args_received
      #[
        #QueryField.new('hello', { "id" => "1" })
      #]

      # test_nested_fields_query
      #[
        #QueryField.new('user', {}, [QueryField.new('name')])
      #]

      ###

      program = []

      while(@current < @tokens.length) do
        program.push(new_parse())
      end

      program
    end

    private

    def new_parse
      token = @tokens[@current]

      if token[:type] == 'str'
        # We are defining a field!
        name = token[:value]

        token = @tokens[@current += 1]

        # We are defining the field's arguments!
        if token[:type] == 'paren'
          arg_tokens = []

          token = @tokens[@current += 1]

          while(token[:type] != 'paren' && token[:value] != ')')
            arg_tokens << token
            token = @tokens[@current += 1]
          end

          arg_tokens << { type: 'arg_sep', value: ',' }

          require 'pry'; binding.pry

          #

          if arg_tokens.length % 3 != 0
            raise ArgumentError, "Improper formatting of arguments for '#{name}' field"
          end

          args = {}

          arg_tokens.each_slice(3) do |arg_tokens_groups|
            arg_tokens_groups.each do |arg_tokens_group|
              require 'pry'; binding.pry
              if arg_tokens_group[1][:type] == 'equalTo'
                args[arg_tokens_group[0]] = arg_tokens_group[2]
              else
                raise ArgumentError, "Improper formatting of argument '#{arg_tokens_group[0]}' for '#{name}' field"
              end
            end
          end

          args

          require 'pry'; binding.pry
        end

        # We are defining the field's fields!
        if token[:type] == 'b'
          token = @tokens[@current += 1]

          while(token[:type] != 'b' && token[:value] != '}')
            ret = new_parse()
            token = @tokens[@current += 1]
          end

          require 'pry'; binding.pry
        end

        QueryField.new(name)
      end

      #@current = @tokens.length

      #QueryField.new('hello')
    end

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

          require 'pry'; binding.pry

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

        if char == ','
          tokens.push({
            type: 'arg_sep',
            value: char
          })

          current += 1
        end

        if char =~ /[a-z0-9]/i
          value = ''

          while(char =~ /[a-z0-9]/i) do
            value += char
            char = @query[current += 1]
          end

          tokens.push({
            type: 'alphanum',
            value: value
          })
        end

        #if char =~ /[0-9]/
          #value = ''

          #while(char =~ /[0-9]/) do
            #value += char
            #char = @query[current += 1]
          #end

          #tokens.push({
            #type: 'num',
            #value: value
          #})
        #end
      end

      add_query_if_necessary(tokens)
      tokens
    end

    private

    def add_query_if_necessary(tokens)
      token = tokens.first

      if token[:type] == 'b'
        tokens.unshift({
          type: 'str',
          value: 'query'
        })
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

  class QueryField
    def initialize(name, args = {}, fields = [])
      @name = name
      @args = args
      @fields = fields
    end

    def args
      @args
    end

    def fields
      @fields
    end

    def name
      @name
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
    query = transform(query)
    result = {}

    require 'pry'; binding.pry
    query.each do |attribute|
      result[attribute.name] = resolve(attribute, @schema, nil, context)
      #@schema[attr]['resolve'].call(nested_attrs["_@params"], context)
    end

    { data: result }
  end

  private

  def resolve(attribute, schema, previous_object, context)
    resolved_parent =
      begin
        if (resolveFunc = schema[attribute.name]['resolve'])
          resolveFunc.call(attribute.args, context)
        else
          previous_object.public_send(attribute.name)
        end
      rescue => e
        raise ArgumentError, "Unable to resolve attribute '#{attribute.name}', got #{e.class}: #{e.message}"
      end

    if attribute.fields.length > 0
      resolved_fields = {}

      attribute.fields.each do |field|
        resolved_fields[field.name] =
          resolve(field, schema[attribute.name]['fields'], resolved_parent, context)
      end

      resolved_fields
    else
      resolved_parent
    end
  end

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
