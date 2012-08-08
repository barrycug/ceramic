class SelectionBuilder
  
  def self.collect_selections(&block)
    builder = self.new
    builder.instance_exec(&block)
    builder.instance_eval { @selections }
  end
  
  Selection = Struct.new(:selection, :context)
  
  def initialize(context = {})
    @context = context
    @selections = []
  end
  
  def conditions(conditions, &block)
    context = merge_conditions(@context, conditions)
    
    builder = self.class.new(context)
    builder.instance_eval(&block)
    
    @selections += builder.instance_eval { @selections }
  end
  
  def select(selection = nil, conditions = {})
    validate_selection(selection)
    context = merge_conditions(@context, conditions)
    
    @selections << Selection.new(selection, context)
  end
  
  protected
  
    # Raise errors if there's a problem with the selection.
  
    def validate_selection(selection)
    end
    
    # Merge the inner condition with outer. If there is no outer condition
    # defined, outer will be nil. This may be overridden by subclasses.
    # The default behavior is to assemble an array of conditions. If there
    # is a problem with merging this particular combination of conditions,
    # an error should be raised.
    
    def merge_condition(key, outer, inner)
      if outer.nil?
        [inner]
      else
        outer + [inner]
      end
    end
    
  private
    
    # Return a context hash with the new conditions merged into it.
    # If there are problems with the conditions, raise an error.
    
    def merge_conditions(context, conditions)
      
      result = {}
      
      context.each do |key, value|
        result[key] = value unless conditions.has_key?(key)
      end
      
      conditions.each do |key, value|
        result[key] = merge_condition(key, context[key], value)
      end
      
      result
      
    end
  
end
