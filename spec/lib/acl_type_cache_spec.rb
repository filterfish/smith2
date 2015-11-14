# -*- encoding: utf-8 -*-

describe Smith::AclTypeCache do

  let(:type_cache) { Smith::AclTypeCache.instance }

  context "String format" do

    before(:each) do
      type_cache.clear!
    end

    it "add a value to the cache" do
      expect(type_cache.dump_types(:string)).to eq({})
      expect(type_cache.dump_hashes(:string)).to eq({})

      type_cache.add(String)
      expect(type_cache.dump_hashes(:string)).to eq("1rdse78" => String)
      expect(type_cache.dump_types(:string)).to eq(String => "1rdse78")
    end

    it "perform a lookup on the hash" do
      type_cache.add(String)
      expect(type_cache.include?('1rdse78')).to eq(true)
    end

    it "perform a lookup on the type" do
      type_cache.add(String)
      expect(type_cache.include?(String, :by_type => true)).to eq(true)
    end

    it "get the hash when given a type" do
      type_cache.add(String)
      type_cache.add("Random string")

      expect(type_cache.get_by_type(String)).to eq('1rdse78')
      expect(type_cache.get_by_type("Random string")).to eq('1kvf4in')
    end

    it "get the type when given a hash" do
      type_cache.add(String)
      type_cache.add("Random string")

      expect(type_cache.get_by_hash('1rdse78')).to eq(String)
      expect(type_cache.get_by_hash('1kvf4in')).to eq("Random string")
    end
  end

  context "Legacy format" do

    before(:each) do
      type_cache.clear!
    end

    it "perform a lookup on the hash" do
      module ACL; module Smith; class LegacyACLType; end; end; end

      type_cache.add(ACL::Smith::LegacyACLType)
      expect(type_cache.get_by_hash('legacy_acl_type')).to eq( ACL::Smith::LegacyACLType)
      expect(type_cache.get_by_hash(:legacy_acl_type)).to eq(ACL::Smith::LegacyACLType)

      type_cache.add(String)
      expect(type_cache.get_by_hash('string')).to eq(String)
    end
  end

  context "Binary format" do

    before(:each) do
      type_cache.clear!
    end

    it "add a value to the cache" do
      expect(type_cache.dump_types(:binary)).to eq({})
      expect(type_cache.dump_hashes(:binary)).to eq({})

      type_cache.add(String)
      expect(type_cache.dump_hashes(:binary)).to eq(3832528868 => String)
      expect(type_cache.dump_types(:binary)).to eq(String =>3832528868 )
    end

    it "perform a lookup on the hash" do
      type_cache.add(String)
      expect(type_cache.include?(3832528868, :format => :binary)).to eq(true)
    end

    it "perform a lookup on the type" do
      type_cache.add(String)
      expect(type_cache.include?(String, :by_type => true, :format => :binary)).to eq(true)
    end

    it "get the hash when given a type" do
      type_cache.add(String)
      type_cache.add("Random string")

      expect(type_cache.get_by_type(String, :binary)).to eq(3832528868)
      expect(type_cache.get_by_type("Random string", :binary)).to eq(3438879647)
    end

    it "get the type when given a hash" do
      type_cache.add(String)
      type_cache.add("Random string")

      expect(type_cache.get_by_hash(3832528868, :binary)).to eq(String)
      expect(type_cache.get_by_hash(3438879647, :binary)).to eq("Random string")
    end
  end

  context "Invalid Format" do
    before(:each) do
      type_cache.clear!
    end

    it "raise an exception when the format is invalid" do
      type_cache.add(String)

      expect {
        type_cache.get_by_hash(3832528868, :foo)
      }.to raise_error(Smith::ACL::UnknownTypeFormat)
    end
  end
end
