module Wonkavision
  module Analytics
    class Query
      attr_reader :axes

      def initialize()
        @axes = []
        @filters = []
        @measures = []
        @from = nil
      end

      def from(cube_name=nil)
        return @from unless cube_name
        @from = cube_name
        self
      end

      def select(*dimensions)
        options = dimensions.extract_options!
        axis = options[:axis] || options[:on]
        axis_ordinal = self.class.axis_ordinal(axis)
        @axes[axis_ordinal] = dimensions.flatten
        self
      end

      [:columns,:rows,:pages,:chapters,:sections].each do |axis|
        eval "def #{axis}(*args);args.add_options!(:axis=>#{axis.inspect});select(*args);end"
      end

      def measures(*measures)
        @measures.concat measures.flatten
      end

      def where(criteria_hash = {})
        criteria_hash.each_pair do |filter,value|
          member_filter = filter.kind_of?(MemberFilter) ? filter :
            MemberFilter.new(filter)
          member_filter.value = value
          add_filter(member_filter)
        end
        self
      end

      def filters
        (@filters + Wonkavision::Analytics.context.global_filters).compact.uniq
      end


      def add_filter(member_filter)
        @filters << member_filter
        self
      end

      def slicer
        filters.select{|f|f.dimension?}.reject{|f|selected_dimensions.include?(f.name)}
      end

      def slicer_dimensions
        slicer.map{ |f|f.name }
      end

      def referenced_dimensions
        ( [] + selected_dimensions.map{|s|s.to_s} + slicer.map{|f|f.name.to_s} ).uniq.compact
      end

      def selected_dimensions
        dimensions = []
        axes.each { |dims|dimensions.concat(dims) unless dims.blank? }
        dimensions.uniq.compact
      end

      def all_dimensions?
        axes.empty?
      end

      def selected_measures
        @measures || []
      end

      def matches_filter?(cube, tuple)
        !( filters.detect{ |filter| !filter.matches(cube, tuple) } )
      end

      def validate!(schema)
        raise "You must specify a 'from' cube in your query" unless @from && cube = schema.cubes[@from]
        axes.each_with_index{|axis,index|raise "Axes must be selected from in consecutive order and contain at least one dimension. Axis #{index} is blank." if axis.blank?}
        selected_measures.each{|measure_name|raise "The measure #{measure_name} cannot be found in #{cube.name}" unless cube.measures[measure_name]}
        raise "No dimensions were selected" unless selected_dimensions.length > 0
        selected_dimensions.each{|dim_name| raise "The dimension #{dim_name} cannot be found in #{cube}" unless cube.dimensions[dim_name]}
        filters.each{|filter| raise "An filter referenced an invalid member:#{filter.to_s}" unless filter.validate!(cube)}
        true
      end     

      def self.axis_ordinal(axis_def)
        case axis_def.to_s.strip.downcase.to_s
        when "columns" then 0
        when "rows" then 1
        when "pages" then 2
        when "chapters" then 3
        when "sections" then 4
        else axis_def.to_i
        end
      end

    end
  end
end