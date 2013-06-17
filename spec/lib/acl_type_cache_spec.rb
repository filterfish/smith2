# -*- encoding: utf-8 -*-

describe Smith::AclTypeCache do

  let(:type_cache) { Smith::AclTypeCache.instance }

  before(:each) do
    type_cache.clear!
  end

  it "should add a value to the cache" do
    type_cache.dump_types.should == {}
    type_cache.dump_hashes.should == {}

    type_cache.add(String)
    type_cache.dump_hashes.should == {"1rdse78" => String}
    type_cache.dump_types.should == {String => "1rdse78"}
  end

  it "should perform a lookup on the hash" do
    type_cache.add(String)
    type_cache.include?('1rdse78').should == true
  end

  it "should perform a lookup on the type" do
    type_cache.add(String)
    type_cache.include?(String, :by_type => true).should == true
  end

  it "should get the hash when given a type" do
    type_cache.add(String)
    type_cache.add("Random string")

    type_cache.get_by_type(String).should == '1rdse78'
    type_cache.get_by_type("Random string").should == '1kvf4in'
  end

  it "should get the type when given a hash" do
    type_cache.add(String)
    type_cache.add("Random string")

    type_cache.get_by_hash('1rdse78').should == String
    type_cache.get_by_hash('1kvf4in').should == "Random string"
  end

  it "should work with legacy types." do
    module ACL; module Smith; class LegacyACLType; end; end; end

    type_cache.add(ACL::Smith::LegacyACLType)
    type_cache.get_by_hash('legacy_acl_type').should == ACL::Smith::LegacyACLType
    type_cache.get_by_hash(:legacy_acl_type).should == ACL::Smith::LegacyACLType

    type_cache.add(String)
    type_cache.get_by_hash('string').should == String
  end
end
