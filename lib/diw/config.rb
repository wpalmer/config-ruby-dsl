module DIW
	module Config
		class Prefix
			def initialize(base, prefix, &block)
				@base = base
				@prefix = [*prefix]

				if !block.nil?
					instance_eval(&block)
				end
			end

			def self.prefixed_method(method)
				define_method method do |path, *args, &block|
					if path.is_a? Hash
						tweaked_path = {}
						path.each do |k,v|
							tweaked_path[ (@prefix + [k.to_s.split(".")]).join(".") ] = v
						end
					else
						tweaked_path = @prefix + [*path]
					end

					@base.send method, tweaked_path, *args, &block
				end
			end

			prefixed_method :section
			prefixed_method :var
			prefixed_method :get
			prefixed_method :has_section?
			prefixed_method :has_var?
			def push(*args, &block)
				@base.push(*args, &block)
			end

			def method_missing(method, *args, &block)
				return super if args.length > 0
				get method, &block
			end
		end

		class Config
			def initialize(frame = nil, &block)
				frame = Frame.new(self) if frame.nil?
				@stack = [frame]

				if !block.nil?
					instance_eval(&block)
				end
			end

			def method_missing(method, *args, &block)
				return super if args.length > 0
				get method, &block
			end
			
			def get(path, &block)
				path = [ *path ]

				if has_section?(path) || !block.nil?
					section(path, &block)
				else
					var(path)
				end
			end

			def has_section?(path)
				path = [ *path ]

				@stack.reverse_each do |frame|
					if frame.has_section?( path )
						return true
					end
				end

				return false
			end

			def section(path, &block)
				path = [ *path ]

				::DIW::Config::Prefix.new(self, path, &block)
			end

			def has_var?(path)
				path = [ *path ]

				if path.length == 0
					nil
				elsif path.length > 1
					@stack.reverse_each do |frame|
						if frame.has_section?( path[0..-2] )
							if frame.has_section_var?( path[0..-2], path.last.to_sym )
								return true
							end
						end
					end

					return false
				else
					@stack.reverse_each do |frame|
						if frame.has_var?( path.last.to_sym )
							return true
						end
					end

					return false
				end
			end

			# retrieve (or set) a var
			#
			# Retrieve a var:
			# var :foo
			#
			# Set a var:
			# var :foo, "newValue"
			#
			# Set multiple vars:
			# var foo: "newValue", bar: "anotherValue"
			def var(path, value = :NOT_PASSED)
				if path.is_a? Hash
					path.each do |k,v|
						var k.to_s.split("."), v
					end

					return path
				end

				path = [ *path ]
				raise ArgumentError.new("Invalid path") if path.length == 0

				## vvv checking if value was passed. If not, we're trying to retrieve an existing value vvv
				if value == :NOT_PASSED
					@stack.reverse_each do |frame|
						if path.length > 1
							# vvv checking for all-but-last of path, as section name vvv
							if frame.has_section?( path[0..-2] )
								# vvv checking if that section contains the last component of the path vvv
								if frame.has_section_var?( path[0..-2], path.last.to_sym )
									return frame.get_section_var( path[0..-2], path.last.to_sym )
								end
							end
						# vvv only one component in path, check if the base of this frame has it as a var vvv
						elsif frame.has_var?( path.last.to_sym )
							return frame.get_var( path.last.to_sym )
						end
					end

					# vvv found nothing, error vvv
					raise ArgumentError.new("Unknown path '#{path}'")
				end

				if path.length > 1
					# vvv iterate over each element of the path, creating sections as needed vvv
					(1..(path.length - 1)).each do |i|
						if !@stack.last.has_section?( path[0..(-1 * i - 1)] )
							@stack.last.set_section( path[0..(-1 * i - 1)] )
						end
					end

					return @stack.last.set_section_var( path[0..-2], path.last.to_sym, value )
				end

				return @stack.last.set_var( path.last.to_sym, value )
			end

			def push(frame = nil, &block)
				frame = Frame.new(self) if frame.nil?
				@stack.push( frame )

				if !block.nil?
					instance_eval(&block)
				end
			end

			def pop
				@stack.pop
				self
			end
		end

		class Frame
			def initialize(cfg)
				@cfg = cfg
				@sections = {}
				@vars = {}
			end

			def has_section?(path)
				@sections.has_key?( path.join "." )
			end

			def set_section(path, vars = {})
				@sections[ path.join "." ] = {}
				vars.each {|k,v| set_section_var path, k, v }
			end

			def has_var?(name)
				@vars.has_key?( name )
			end

			def get_var(name)
				value = @vars[ name ]
				if value.respond_to? :call
					return value.call(@cfg)
				else
					return value
				end
			end

			def set_var(name, value)
				@vars[ name ] = value
			end

			def has_section_var?(section_path, name)
				has_section?(section_path) and @sections[section_path.join "."].has_key?(name)
			end

			def get_section_var(section_path, name)
				value = @sections[section_path.join "."][ name ]
				if value.respond_to? :call
					return value.call(@cfg)
				else
					return value
				end
			end

			def set_section_var(section_path, name, value)
				@sections[section_path.join "."][ name ] = value
			end
		end
	end
end
