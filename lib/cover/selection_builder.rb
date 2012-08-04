class SelectionBuilder
  
  def self.collect_selections(&block)
    builder = self.new
    builder.instance_exec(&block)
    builder.instance_eval { @selections }
  end
  
  Selection = Struct.new(:selection, :conditions)
  
  def initialize(context = [])
    @context = context
    @selections = []
  end
  
  def conditions(conditions, &block)
    conditions = parse_conditions(conditions)
    validate_context(@context + [conditions])
    
    builder = SelectionBuilder.new(@context + [conditions])
    builder.instance_eval(&block)
    
    @selections += builder.instance_eval { @selections }
  end
  
  def select(selection = nil, conditions)
    conditions = parse_conditions(conditions)
    
    validate_selection(selection)
    validate_context(@context + [conditions])
    
    @selections << Selection.new(selection, @context + [conditions])
  end
  
  protected
  
    def validate_selection(selection)
    end
    
    def parse_conditions(conditions)
      conditions
    end
    
    def validate_context(context)
    end
  
end
