# -*- encoding: utf-8 -*-
require 'smith/acl_parser'

describe Smith::ACLParser do

  let(:another_single_clazz) {
    %{
      ##
      # This file is auto-generated. DO NOT EDIT!
      #
      require 'protobuf/message'

      module Smith
        module ACL

          ##
          # Message Classes
          #
          class AgentCommand < ::Protobuf::Message; end

          ##
          # Message Fields
          #
          class AgentCommand
            required ::Protobuf::Field::StringField, :command, 1
            repeated ::Protobuf::Field::StringField, :options, 2
          end
        end
      end
     }
  }

  let(:single_clazz) {
    %{
      ##
      # This file is auto-generated. DO NOT EDIT!
      #
      require 'protobuf/message'

      module Smith
        module ACL

          ##
          # Message Classes
          #
          class DdgSearch < ::Protobuf::Message; end

          ##
          # Message Fields
          #
          class DdgSearch
            required ::Protobuf::Field::StringField, :query, 1
            optional ::Protobuf::Field::StringField, :paging, 2
          end
        end
      end}
  }

  let(:multiple_clazz) {
    %{
      ##
      # This file is auto-generated. DO NOT EDIT!
      #
      require 'protobuf/message'

      module Smith
        module ACL

          ##
          # Message Classes
          #
          class AgencyCommand < ::Protobuf::Message; end
          class AgencyCommandResponse < ::Protobuf::Message; end

          ##
          # Message Fields
          #
          class AgencyCommand
            required ::Protobuf::Field::StringField, :command, 1
            repeated ::Protobuf::Field::StringField, :args, 2
          end

          class AgencyCommandResponse
            optional ::Protobuf::Field::StringField, :response, 1
          end

        end
      end}
  }

  let(:parser) { Smith::ACLParser.new }

  before(:each) do
  end

  it "parse a single class per module" do
    parser.go(single_clazz)
    parser.fully_qualified_classes.should == [[:Smith, :ACL, :DdgSearch]]
  end

  it "parse multiple single classes per module" do
    parser.go(single_clazz)
    parser.go(another_single_clazz)

    parser.fully_qualified_classes.should == [[:Smith, :ACL, :DdgSearch], [:Smith, :ACL, :AgentCommand]]
  end

  it "parse multiple classes per module" do
    parser.go(multiple_clazz)
    parser.fully_qualified_classes.should == [[:Smith, :ACL, :AgencyCommand], [:Smith, :ACL, :AgencyCommandResponse]]
  end
end
