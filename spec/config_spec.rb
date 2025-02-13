# frozen_string_literal: true

require "spec_helper"

describe Confset do
  before :each do
    Confset.reset
  end

  it "should get setting files" do
    config = Confset.setting_files("root/config", "staging")
    expect(config).to eq([
                           "root/config/settings.yml",
                           "root/config/settings/staging.yml",
                           "root/config/environments/staging.yml",
                           "root/config/settings.local.yml",
                           "root/config/settings/staging.local.yml",
                           "root/config/environments/staging.local.yml"
                         ])
  end

  it "should ignore local config in test environment" do
    config = Confset.setting_files("root/config", "test")
    expect(config).to eq([
                           "root/config/settings.yml",
                           "root/config/settings/test.yml",
                           "root/config/environments/test.yml",
                           "root/config/settings/test.local.yml",
                           "root/config/environments/test.local.yml"
                         ])
  end

  it "should load a basic config file" do
    config = Confset.load_files("spec/fixtures/settings.yml")
    expect(config.size).to eq(1)
    expect(config.server).to eq("google.com")
    expect(config["1"]).to eq("one")
    expect(config.photo_sizes.avatar).to eq([60, 60])
    expect(config.root["yahoo.com"]).to eq(2)
    expect(config.root["google.com"]).to eq(3)
  end

  it "should load 2 basic config files" do
    config = Confset.load_files("spec/fixtures/settings.yml", "spec/fixtures/settings2.yml")
    expect(config.size).to eq(1)
    expect(config.server).to eq("google.com")
    expect(config.another).to eq("something")
  end

  it "should load config files specified as Pathname objects" do
    path = Pathname.new("spec/fixtures").join("settings.yml")
    config = Confset.load_files(path)
    expect(config.server).to eq("google.com")
  end

  it "should load config files specified as objects responding to :load" do
    source = double "source"
    allow(source).to receive(:load) do
      { "server" => "google.com" }
    end
    config = Confset.load_files(source)
    expect(config.server).to eq("google.com")
  end

  it "should load config from HashSource" do
    source = Confset::Sources::HashSource.new({ "server" => "google.com" })
    config = Confset.load_files(source)
    expect(config.server).to eq("google.com")
  end

  it "should load config from files and HashSource" do
    file_source = "spec/fixtures/settings.yml"
    hash_source = Confset::Sources::HashSource.new({ "size" => 12 })
    config = Confset.load_files(file_source, hash_source)
    expect(config.server).to eq("google.com")
    expect(config.size).to eq(12)
  end

  it "should load empty config for a missing file path" do
    config = Confset.load_files("spec/fixtures/some_file_that_doesnt_exist.yml")
    expect(config).to be_empty
  end

  it "should load an empty config for multiple missing file paths" do
    files  = ["spec/fixtures/doesnt_exist1.yml", "spec/fixtures/doesnt_exist2.yml"]
    config = Confset.load_files(files)
    expect(config).to be_empty
  end

  it "should load empty config for an empty setting file" do
    config = Confset.load_files("spec/fixtures/empty1.yml")
    expect(config).to be_empty
  end

  it "should convert to a hash" do
    config = Confset.load_files("spec/fixtures/development.yml").to_hash
    expect(config[:section][:servers]).to be_kind_of(Array)
    expect(config[:section][:servers][0][:name]).to eq("yahoo.com")
    expect(config[:section][:servers][1][:name]).to eq("amazon.com")
  end

  it "should convert to a hash (We Need To Go Deeper)" do
    config  = Confset.load_files("spec/fixtures/development.yml").to_hash
    servers = config[:section][:servers]
    expect(servers).to eq([{ name: "yahoo.com" }, { name: "amazon.com" }])
  end

  it "should convert to a hash without modifying nested settings" do
    config = Confset.load_files("spec/fixtures/development.yml")
    config.to_hash
    expect(config).to be_kind_of(Confset::Options)
    expect(config[:section]).to be_kind_of(Confset::Options)
    expect(config[:section][:servers][0]).to be_kind_of(Confset::Options)
    expect(config[:section][:servers][1]).to be_kind_of(Confset::Options)
  end

  it "should convert to a hash without modifying nested settings" do
    config = Confset.load_files("spec/fixtures/development.yml")
    config.to_h
    expect(config).to be_kind_of(Confset::Options)
    expect(config[:section]).to be_kind_of(Confset::Options)
    expect(config[:section][:servers][0]).to be_kind_of(Confset::Options)
    expect(config[:section][:servers][1]).to be_kind_of(Confset::Options)
  end

  it "should convert to a json" do
    config = Confset.load_files("spec/fixtures/development.yml").to_json
    expect(JSON.parse(config)["section"]["servers"]).to be_kind_of(Array)
  end

  it "should load an empty config for multiple missing file paths" do
    files  = ["spec/fixtures/empty1.yml", "spec/fixtures/empty2.yml"]
    config = Confset.load_files(files)
    expect(config).to be_empty
  end

  it "should allow overrides" do
    files  = ["spec/fixtures/settings.yml", "spec/fixtures/development.yml"]
    config = Confset.load_files(files)
    expect(config.server).to eq("google.com")
    expect(config.size).to eq(2)
  end

  it "should allow full reload of the settings files" do
    files = ["spec/fixtures/settings.yml"]
    Confset.load_and_set_settings(files)
    expect(Settings.server).to eq("google.com")
    expect(Settings.size).to eq(1)

    files = ["spec/fixtures/settings.yml", "spec/fixtures/development.yml"]
    Settings.reload_from_files(files)
    expect(Settings.server).to eq("google.com")
    expect(Settings.size).to eq(2)
  end



  context "Nested Settings" do
    let(:config) do
      Confset.load_files("spec/fixtures/development.yml")
    end

    it "should allow nested sections" do
      expect(config.section.size).to eq(3)
    end

    it "should allow configuration collections (arrays)" do
      expect(config.section.servers[0].name).to eq("yahoo.com")
      expect(config.section.servers[1].name).to eq("amazon.com")
    end
  end

  context "Settings with ERB tags" do
    let(:config) do
      Confset.load_files("spec/fixtures/with_erb.yml")
    end

    it "should evaluate ERB tags" do
      expect(config.computed).to eq(6)
    end

    it "should evaluated nested ERB tags" do
      expect(config.section.computed1).to eq(1)
      expect(config.section.computed2).to eq(2)
    end
  end


  context "Boolean Overrides" do
    let(:config) do
      files = ["spec/fixtures/bool_override/config1.yml", "spec/fixtures/bool_override/config2.yml"]
      Confset.load_files(files)
    end

    it "should allow overriding of bool settings" do
      expect(config.override_bool).to eq(false)
      expect(config.override_bool_opposite).to eq(true)
    end
  end

  context "Custom Configuration" do
    it "should have the default settings constant as 'Settings'" do
      expect(Confset.const_name).to eq("Settings")
    end

    it "should be able to assign a different settings constant" do
      Confset.setup { |config| config.const_name = "Settings2" }

      expect(Confset.const_name).to eq("Settings2")
    end
  end

  context "Settings with a type value of 'hash'" do
    let(:config) do
      files = ["spec/fixtures/custom_types/hash.yml"]
      Confset.load_files(files)
    end

    it "should turn that setting into a Real Hash" do
      expect(config.prices).to be_kind_of(Hash)
    end

    it "should map the hash values correctly" do
      expect(config.prices[1]).to eq(2.99)
      expect(config.prices[5]).to eq(9.99)
      expect(config.prices[15]).to eq(19.99)
      expect(config.prices[30]).to eq(29.99)
    end
  end

  context "Merging hash at runtime" do
    let(:config) { Confset.load_files("spec/fixtures/settings.yml") }
    let(:hash) { { :options => { :suboption => "value" }, :server => "amazon.com" } }

    it "should be chainable" do
      expect(config.merge!({})).to eq(config)
    end

    it "should preserve existing keys" do
      expect { config.merge!({}) }.to_not change { config.keys }
    end

    it "should recursively merge keys" do
      config.merge!(hash)
      expect(config.options.suboption).to eq("value")
    end

    it "should rewrite a merged value" do
      expect { config.merge!(hash) }.to change { config.server }.from("google.com").to("amazon.com")
    end
  end

  context "Merging nested hash at runtime" do
    let(:config) { Confset.load_files("spec/fixtures/deep_merge/config1.yml") }
    let(:hash) { { inner: { something1: "changed1", something3: "changed3" } } }
    let(:hash_with_nil) { { inner: { something1: nil } } }

    it "should preserve first level keys" do
      expect { config.merge!(hash) }.to_not change { config.keys }
    end

    it "should preserve nested key" do
      config.merge!(hash)
      expect(config.inner.something2).to eq("blah2")
    end

    it "should add new nested key" do
      expect { config.merge!(hash) }
        .to change { config.inner.something3 }.from(nil).to("changed3")
    end

    it "should rewrite a merged value" do
      expect { config.merge!(hash) }
        .to change { config.inner.something1 }.from("blah1").to("changed1")
    end

    it "should update a string to nil " do
      expect { config.merge!(hash_with_nil) }
        .to change { config.inner.something1 }.from("blah1").to(nil)
    end

    it "should update something nil to true" do
      expect { config.merge!(inner: { somethingnil: true }) }
        .to change { config.inner.somethingnil }.from(nil).to(true)
    end

    it "should update something nil to false" do
      expect { config.merge!(inner: { somethingnil: false }) }
        .to change { config.inner.somethingnil }.from(nil).to(false)
    end

    it "should update something false to true" do
      expect { config.merge!(inner: { somethingfalse: true }) }
        .to change { config.inner.somethingfalse }.from(false).to(true)
    end

    it "should update something false to nil" do
      expect { config.merge!(inner: { somethingfalse: nil }) }
        .to change { config.inner.somethingfalse }.from(false).to(nil)
    end

    it "should update something true to false" do
      expect { config.merge!(inner: { somethingtrue: false }) }
        .to change { config.inner.somethingtrue }.from(true).to(false)
    end

    it "should update something true to nil" do
      expect { config.merge!(inner: { somethingtrue: nil }) }
        .to change { config.inner.somethingtrue }.from(true).to(nil)
    end

    context "with Confset.merge_nil_values = false" do
      let(:config) do
        Confset.merge_nil_values = false
        Confset.load_files("spec/fixtures/deep_merge/config1.yml")
      end

      it "should not overwrite values with nil" do
        old_value = config.inner.something1
        config.merge!(hash_with_nil)
        expect(config.inner.something1).to eq(old_value)
      end
    end
  end

  context "[] accessors" do
    let(:config) do
      files = ["spec/fixtures/development.yml"]
      Confset.load_files(files)
    end

    it "should access attributes using []" do
      expect(config.section["size"]).to eq(3)
      expect(config.section[:size]).to eq(3)
      expect(config[:section][:size]).to eq(3)
    end

    it "should set values using []=" do
      config.section[:foo] = "bar"
      expect(config.section.foo).to eq("bar")
    end
  end

  context "enumerable" do
    let(:config) do
      files = ["spec/fixtures/development.yml"]
      Confset.load_files(files)
    end

    it "should enumerate top level parameters" do
      keys = []
      config.each { |key, value| keys << key }
      expect(keys).to eq([:size, :section])
    end

    it "should enumerate inner parameters" do
      keys = []
      config.section.each { |key, value| keys << key }
      expect(keys).to eq([:size, :servers])
    end

    it "should have methods defined by Enumerable" do
      expect(config.map { |key, value| key }).to eq([:size, :section])
    end
  end

  context "keys" do
    let(:config) do
      files = ["spec/fixtures/development.yml"]
      Confset.load_files(files)
    end

    it "should return array of keys" do
      expect(config.keys).to contain_exactly(:size, :section)
    end

    it "should return array of keys for nested entry" do
      expect(config.section.keys).to contain_exactly(:size, :servers)
    end
  end

  context "when loading settings files" do
    context "using knockout_prefix" do
      context "in configuration phase" do
        it "should be able to assign a different knockout_prefix value" do
          Confset.knockout_prefix = "--"

          expect(Confset.knockout_prefix).to eq("--")
        end

        it "should have the default knockout_prefix value equal nil" do
          expect(Confset.knockout_prefix).to eq(nil)
        end
      end

      context "merging" do
        let(:config) do
          Confset.knockout_prefix = "--"
          Confset.overwrite_arrays = false
          Confset.load_files(["spec/fixtures/knockout_prefix/config1.yml",
                             "spec/fixtures/knockout_prefix/config2.yml",
                             "spec/fixtures/knockout_prefix/config3.yml"])
        end

        it "should remove elements from settings" do
          expect(config.array1).to eq(["item4", "item5", "item6"])
          expect(config.array2.inner).to eq(["item4", "item5", "item6"])
          expect(config.array3).to eq("")
          expect(config.string1).to eq("")
          expect(config.string2).to eq("")
          expect(config.hash1.to_hash).to eq({ key1: "", key2: "", key3: "value3" })
          expect(config.hash2).to eq("")
          expect(config.hash3.to_hash).to eq({ key4: "value4", key5: "value5" })
          expect(config.fixnum1).to eq("")
          expect(config.fixnum2).to eq("")
        end
      end
    end

    context "using overwrite_arrays" do
      context "in configuration phase" do
        it "should be able to assign a different overwrite_arrays value" do
          Confset.overwrite_arrays = false

          expect(Confset.overwrite_arrays).to eq(false)
        end

        it "should have the default overwrite_arrays value equal false" do
          expect(Confset.overwrite_arrays).to eq(true)
        end
      end

      context "overwriting" do
        let(:config) do
          Confset.overwrite_arrays = true
          Confset.load_files(["spec/fixtures/overwrite_arrays/config1.yml",
                             "spec/fixtures/overwrite_arrays/config2.yml",
                             "spec/fixtures/overwrite_arrays/config3.yml"])
        end

        it "should remove elements from settings" do
          expect(config.array1).to eq(["item4", "item5", "item6"])
          expect(config.array2.inner).to eq(["item4", "item5", "item6"])
          expect(config.array3).to eq([])
        end
      end


      context "merging" do
        let(:config) do
          Confset.overwrite_arrays = false
          Confset.load_files(["spec/fixtures/deep_merge/config1.yml",
                             "spec/fixtures/deep_merge/config2.yml"])
        end

        it "should merge hashes from multiple configs" do
          expect(config.inner.marshal_dump.keys.size).to eq(6)
          expect(config.inner2.inner2_inner.marshal_dump.keys.size).to eq(3)
        end

        it "should merge arrays from multiple configs" do
          expect(config.arraylist1.size).to eq(6)
          expect(config.arraylist2.inner.size).to eq(6)
        end
      end
    end
  end
end
