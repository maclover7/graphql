tokens = [
  {:type=>"lb", :value=>"{"},
  {:type=>"str", :value=>"user"},
  {:type=>"lb", :value=>"{"},
  {:type=>"str", :value=>"name"},
  {:type=>"rb", :value=>"}"},
  {:type=>"rb", :value=>"}"}
]

def parse(tokens)
  [
    "user" => [
      "name" => nil
    ]
  ]
end

parse(tokens)
