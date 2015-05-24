require 'smith/utils'
require 'smith/commands/common'
module Smith
  module Commands
    class CUT
      include Common
    end
  end
end

describe Smith::Utils do

  context "class_name_from_path" do
    let(:pathname) { Pathname.new('group/namespace/foo') }

    it 'convert a pathname to fully qualified Class name.' do
      class_name = Smith::Utils.class_name_from_path(pathname)
      expect(class_name).to eq("Group::Namespace::Foo")
    end

    it 'convert a relative pathname to fully qualified Class name.' do
      class_name = Smith::Utils.class_name_from_path(pathname,  Pathname.new('group'))
      expect(class_name).to eq("Namespace::Foo")
    end
  end
end
