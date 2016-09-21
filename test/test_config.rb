require 'test/unit'
require 'diw/config'

class ConfigTest < Test::Unit::TestCase
	def test_bare_var
		cfg = ::DIW::Config::Config.new do
			var :bareVar, "bareVarValue"
		end
		assert_equal "bareVarValue", cfg.bareVar
	end

	def test_bare_var_hash
		cfg = ::DIW::Config::Config.new do
			var bareVar: "bareVarValue"
		end
		assert_equal "bareVarValue", cfg.bareVar
	end

	def test_section_var
		cfg = ::DIW::Config::Config.new do
			section :aSection do
				var :aVar, "sectionVarValue"
			end
		end
		assert_equal "sectionVarValue", cfg.aSection.aVar
	end

	def test_section_var_hash
		cfg = ::DIW::Config::Config.new do
			section :aSection do
				var aVar: "sectionVarValue"
			end
		end
		assert_equal "sectionVarValue", cfg.aSection.aVar
	end

	def test_subsection_var
		cfg = ::DIW::Config::Config.new do
			section :aSection do
				section :aSubSection do
					var :aVar, "subsectionVarValue"
				end
			end
		end
		assert_equal "subsectionVarValue", cfg.aSection.aSubSection.aVar
	end

	def test_subsection_var_hash
		cfg = ::DIW::Config::Config.new do
			section :aSection do
				section :aSubSection do
					var aVar: "subsectionVarValue"
				end
			end
		end
		assert_equal "subsectionVarValue", cfg.aSection.aSubSection.aVar
	end

	def test_stack
		cfg = ::DIW::Config::Config.new do
			var a: "aVar", b: "bVar"
			section :aSection do
				var a: "aSectionVar", b: "bSectionVar"
			end
		end

		cfg.push do
			var a: "overrideVar"
			section :aSection do
				var a: "sectionOverrideVar"
			end
		end

		assert_equal "overrideVar", cfg.a
		assert_equal "sectionOverrideVar", cfg.aSection.a
		assert_equal "bVar", cfg.b
		assert_equal "bSectionVar", cfg.aSection.b

		cfg.pop

		assert_equal "aVar", cfg.a
		assert_equal "aSectionVar", cfg.aSection.a
		assert_equal "bVar", cfg.b
		assert_equal "bSectionVar", cfg.aSection.b
	end

	def test_complex
		cfg = ::DIW::Config::Config.new do
			var a: Module.new {
				def self.method_missing(method)
					::DIW::Config::Config.new do
						var \
							foo: "generatedFoo:" + method.to_s,
							bar: "generatedBar:" + method.to_s
					end
				end
			}
		end

		assert_equal "generatedBar:neverDefined", cfg.a.neverDefined.bar
	end
end
