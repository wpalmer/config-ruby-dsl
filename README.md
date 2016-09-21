### DIW::Config

A ruby DSL for defining and accessing configuration data.

Main features:

  - method-style variable access
  - "sections" for grouping collections of variables
  - a "stack" onto which collections of variables can be `push`ed and `pop`ped
  - just-in-time calculations for any value responding to a `call` method

Example:

    require 'diw/config'

    cfg = ::DIW::Config::Config.new do
        section :aSection do
            var :aVariableName, "aVariableValue"
        end

        section :anotherSection do
            section :aSubSection do
                var :aVariableName, "anotherValue"
                var :aCalculatedValue, Proc.new { "a calculated value" }
            end
        end
    end

    puts cfg.anotherSection.aSubSection.aVariableName
    # => anotherValue

    puts cfg.anotherSection.aSubSection.aCalculatedValue
    # => a calculated value

    cfg.push do
        section :anotherSection
            section :aSubSection do
                var :aVariableName, "aStackOverride"
            end
        end
    end

    puts cfg.anotherSection.aSubSection.aVariableName
    # => aStackOverride
