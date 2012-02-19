module SmugRaw
class Request

  def initialize(smugmug = nil) # :nodoc:
    @smugmug = smugmug
    self.class.smugmug_objects.each { |name|
      klass = self.class.const_get name.capitalize
      instance_variable_set "@#{name}", klass.new(@smugmug)
    }
  end

  def self.build_request(req) # :nodoc:
    method_nesting = req.split '.'
    raise "'#{@name}' : Method name mismatch" if method_nesting.shift != request_name.split('.').last
    if method_nesting.size > 1
      name = method_nesting.first
      class_name = name.capitalize
      if smugmug_objects.include? name
        klass = const_get(class_name)
      else
        klass = Class.new Request
        const_set(class_name, klass)
        attr_reader name
        smugmug_objects << name
      end
      klass.build_request method_nesting.join('.')
    else
      req = method_nesting.first
      module_eval %{
        def #{req}(*args, &block)
          @smugmug.call("#{request_name}.#{req}", *args, &block)
        end
      }
      smugmug_methods << req
    end
  end

  # List the smugmug subobjects of this object
  def self.smugmug_objects; @smugmug_objects ||= [] end

  # List the smugmug methods of this object
  def self.smugmug_methods; @smugmug_methods ||= [] end

  # Returns the prefix of the request corresponding to this class.
  def self.request_name; name.downcase.gsub(/::/, '.').sub(/[^\.]+\./, '') end
end

end

