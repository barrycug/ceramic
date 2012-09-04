require "pg"

module Cover

  class PostGISQuery
    
    def self.build_exec_arguments(query, parameters)
      result = query.to_s
      numbered = []

      parameters.each do |name, (value, type)|
        if result.gsub!(":#{name}", "$#{numbered.size + 1}::#{type}")
          numbered << value
        end
      end

      [result, numbered]
    end

    # :table -- name of table to query
    # :columns -- hash, keys are column names, values are sql expressions
    # :geometry -- hash, keys are column names, values are arrays of wrap expressions
    # :group -- if present, an array of column names to include in group by clause
    # :conditions -- sql conditions besides intersection
    # :intersection_geometry_column -- column to use for intersection
  
    def initialize(options = {})
      @options = options
    end
  
    def to_s
      "SELECT #{outer_select_items} " +
      "FROM (#{outer_table}) q " +
      "WHERE #{outer_conditions}"
    end
  
    protected
  
      def outer_select_items
        (outer_geometry_select_items + outer_column_select_items).join(", ")
      end
    
      def outer_geometry_select_items
        @options[:geometry].map { |column, _| "ST_AsGeoJSON(#{quote_identifier(column)}, 0) AS #{quote_identifier(column)}" }
      end
    
      def outer_column_select_items
        if @options[:columns]
          @options[:columns].map { |column, _| quote_identifier(column) }
        else
          []
        end
      end
    
      def outer_table
        table = ""
        table << "SELECT #{inner_select_items} "
        table << "FROM #{inner_table} "
        table << "WHERE #{inner_conditions} "
        table << "GROUP BY #{inner_group} " if @options[:group]
        table
      end
    
      def outer_conditions
        @options[:geometry].map { |column, _| "NOT ST_IsEmpty(#{column})" }.join(" AND ")
      end
    
      def inner_select_items
        (inner_geometry_select_items + inner_column_select_items).join(", ")
      end
    
      def inner_geometry_select_items
        @options[:geometry].map { |column, wrap_expressions| compose_wrap_expressions(wrap_expressions) + " AS " + quote_identifier(column) }
      end
    
      def inner_column_select_items
        if @options[:columns]
          @options[:columns].map { |column, expression| expression + " AS " + quote_identifier(column) }
        else
          []
        end
      end
    
      def inner_table
        @options[:table]
      end
    
      def inner_conditions
        if @options[:conditions]
          "(#{@options[:conditions]}) AND #{inner_intersection_condition}"
        else
          inner_intersection_condition
        end
      end
    
      def inner_intersection_condition
        "#{quote_identifier(@options[:intersection_geometry_column])} && ST_MakeEnvelope(:left, :top, :right, :bottom, :srid)"
      end
    
      def inner_group
        if String === @options[:group]
          @options[:group]
        else
          @options[:group].map { |column| quote_identifier(column) }.join(", ")
        end
      end
    
      def quote_identifier(name)
        if Symbol === name
          PG::Connection.quote_ident(name.to_s)
        else
          name
        end
      end
    
      def compose_wrap_expressions(wrap_expressions)
        if wrap_expressions.size == 1
          quote_identifier(wrap_expressions.first)
        elsif wrap_expressions.first.include?("$")
          wrap_expressions.first.sub("$", compose_wrap_expressions(wrap_expressions[1..-1]))
        else
          quote_identifier(wrap_expressions.first)
        end
      end
  
  end

end