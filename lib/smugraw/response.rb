module SmugRaw
class Response

  def self.build(h, type) # :nodoc:
    if h.is_a? Response
      h
    elsif h.is_a? Hash and type == 'Methods'
      h['Name']
    elsif h.is_a? Array
      n = h.collect { |e| Response.build(e, type)}
      ResponseList.new({type => h}, type, n)
#     ResponseList.new(h, type, h.collect {|e| Response.build(e, type)})
#    elsif type =~ /s$/ and (a = h[type]).is_a? Array
#      ResponseList.new(h, type, a.collect {|e| Response.build(e, $`)})
#    elsif type =~ /Methods$/ and (a = h['Methods']).is_a? Array
#      ResponseList.new(h, type, a.collect {|e| Response.build(e, $`)})
#    elsif type =~ /s$/ and (a = h[$`]).is_a? Array
#      ResponseList.new(h, type, a.collect {|e| Response.build(e, $`)})
    else
      Response.new(h, type)
    end
  end

  attr_reader :smugmug_type
  def initialize(h, type) # :nodoc:
    @smugmug_type, @h = type, {}
    methods = "class << self;"
    h.each {|k,v|
      @h[k] = case v
        when Hash  then Response.build(v, k)
        when Array then v.collect {|e| Response.build(e, k)}
        else v
      end
      methods << "def #{k}; @h['#{k}'] end;"
    }
    eval methods << "end"
  end
  def [](k); @h[k] end
  def []=(k,v); @h[k] = v end
  #def to_s; @h["_content"] || super end
  #def to_s; @h["Name"] || super end
  def to_s; JSON.pretty_generate(@h); end
  def inspect; @h.inspect end
  def to_hash
    h = { }
    @h.each_pair { |k,v|
      h[k] = v.is_a?(Response) ? v.to_hash : v
    }
    h
  end
  def marshal_dump; [@h, @smugmug_type] end
  def marshal_load(data); initialize(*data) end
end

class ResponseList < Response
  include Enumerable
  def initialize(h, t, a); super(h, t); @a = a end
  def [](k); k.is_a?(Fixnum) ? @a[k] : super(k) end
  def each; @a.each{|e| yield e} end
  def to_a; @a end
  def inspect; @a.inspect end
  def size; @a.size end
  def marshal_dump; [@h, @smugmug_type, @a] end
  alias length size
end

class FailedResponse < StandardError
  attr_reader :code
  alias :msg :message
  def initialize(msg, code, req)
    @code = code
    super("'#{req}' - #{msg}")
  end
end

end

