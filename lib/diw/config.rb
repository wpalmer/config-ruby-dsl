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
			def initialize(&block)
				@stack = [{vars: {}, sections: {}}]

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
					if frame[:sections].has_key?( path.join "." )
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
						if frame[:sections].has_key?( path[0..-2].join "." )
							if frame[:sections][ path[0..-2].join "." ].has_key?( path.last.to_sym )
								return true
							end
						end
					end

					return false
				else
					@stack.reverse_each do |frame|
						if frame[:vars].has_key?( path.last.to_sym )
							return true
						end
					end

					return false
				end
			end

			def var(path, value = :NOT_PASSED)
				if path.is_a? Hash
					path.each do |k,v|
						var k.to_s.split("."), v
					end

					return path
				end

				path = [ *path ]
				raise ArgumentError.new("Invalid path") if path.length == 0

				if value == :NOT_PASSED
					@stack.reverse_each do |frame|
						if path.length > 1
							if frame[:sections].has_key?( path[0..-2].join "." )
								if frame[:sections][ path[0..-2].join "." ].has_key?( path.last.to_sym )
									value = frame[:sections][ path[0..-2].join "." ][ path.last.to_sym ]
									if value.respond_to? :call
										return value.call(self)
									else
										return value
									end
								end
							end
						elsif frame[:vars].has_key?( path.last.to_sym )
							value = frame[:vars][ path.last.to_sym ]
							if value.respond_to? :call
								return value.call(self)
							else
								return value
							end
						end
					end

					raise ArgumentError.new("Unknown path '#{path}'")
				end

				if path.length > 1
					(1..(path.length - 1)).each do |i|
						if !@stack.last[:sections].has_key?( path[0..(-1 * i - 1)].join "." )
							@stack.last[:sections][ path[0..(-1 * i - 1)].join "." ] = { }
						end
					end

					return @stack.last[:sections][ path[0..-2].join "." ][ path.last.to_sym ] = value
				end

				return @stack.last[:vars][ path.last.to_sym ] = value
			end

			def push(&block)
				@stack.push({vars: {}, sections: {}})
				instance_eval &block
			end

			def pop
				@stack.pop
				self
			end
		end
	end
end
