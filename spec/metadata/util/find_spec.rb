require 'spec_helper'
require 'metadata/util/find_class_methods'

describe FindClassMethods, "find for SSA and support methods)" do
  describe "::glob_depth" do
    it "should return the find depth required for the glob pattern" do
      expect(FindClassMethods.glob_depth("*")).to           eq(1)
      expect(FindClassMethods.glob_depth("*/*")).to         eq(2)
      expect(FindClassMethods.glob_depth("*/*/*.rb")).to    eq(3)
      expect(FindClassMethods.glob_depth("**")).to          eq(nil)
      expect(FindClassMethods.glob_depth("*.d/**/*.rb")).to eq(nil)
    end
  end

  describe "::glob_str?" do
    it "should return false when string isn't a glob" do
      expect(FindClassMethods.glob_str?("hello")).to be false
    end

    it "should return true when string is a glob" do
      expect(FindClassMethods.glob_str?("*.rb")).to   be true
      expect(FindClassMethods.glob_str?("foo.r?")).to be true
    end

    it "should return false when glob characters are escaped" do
      expect(FindClassMethods.glob_str?("\\*.rb")).to   be false
      expect(FindClassMethods.glob_str?("foo.r\\?")).to be false
    end
  end

  describe "::path_components" do
    it "should return no components with a glob path with no globs" do
      expect(FindClassMethods.path_components(Pathname.new("spec/foo.rb"), "/")).to match_array([])
    end

    it "should return one component with a glob path with one glob" do
      expect(FindClassMethods.path_components(Pathname.new("spec/*.rb"), "/")).to match_array(["*.rb"])
    end
  end
end
