module Wonkavision
  module Analytics
    module Persistence
      class HashStore < Store

        attr_reader :storage
        def initialize(facts, storage = HashWithIndifferentAccess.new)
          super(facts)
          @storage = storage
        end

        def aggregations
          @storage[:aggregations] ||= {}
        end

        def[](record_id)
          @storage[record_id]
        end

        protected

        def aggregation_key(aggregation_data)
          {
            :dimension_keys => aggregation_data[:dimension_keys],
            :dimension_names => aggregation_data[:dimension_names]
          }
        end

        def purge!
          @storage.clear
        end

        def fetch_facts(aggregation,filters,options={})
          matches = []
          @storage.each_pair do |record_id,facts|
            next if record_id == :aggregations
            failed = filters.detect do |filter|
              attributes = attributes_for(aggregation,filter,facts)
              data = attributes[filter.attribute_key(aggregation)]
              !filter.matches_value(data)
            end
            matches << facts unless failed
          end
          matches
        end

        #Fact persistence
        def update_facts_record(record_id, data)
          previous_facts = @storage[record_id]
          current_facts = @storage[record_id] = (previous_facts ||  {}).merge(data)
          [previous_facts, current_facts]
        end

        def insert_facts_record(record_id, data)
          @storage[record_id] = data
        end

        def delete_facts_record(record_id, data)
          @storage.delete(record_id)
        end

        def attributes_for(aggregation, filter, facts)
          if filter.dimension?
            dimension = aggregation.dimensions[filter.name]
            dimension.complex? ? facts[dimension.from] : facts
          else
            facts
          end
        end

        #Aggregation persistence
        def fetch_tuples(dimension_names = [], filters = [], &block)
          tuples = get_tuples(dimension_names, filters)
          #tuples = tuples.map{|t|block.call(t)} if block
          tuples.map{|t|record_to_row(t)} 
        end

        def get_tuples(dimension_names = [], filters = [])
          return aggregations.values if dimension_names.blank?
          tuples = []
          aggregations.each_pair do |agg_key, agg|
            tuples << agg if
              agg_key[:dimension_names] == dimension_names
          end
          tuples
        end
       
        def record_to_row(record)
          row = {}
          record["dimensions"].each_pair do |dim_name, dim_fields|
            dim_fields.each_pair do |field_name,field_val|
              row["#{dim_name}_#{field_name}"] = field_val
            end
          end
          record["measures"].each_pair do |m_name, m_fields|
            m_fields.each_pair do |field_name, field_val|
              row["#{m_name}_#{field_name}"] = field_val
            end
          end
          row
        end

      end
    end
  end
end