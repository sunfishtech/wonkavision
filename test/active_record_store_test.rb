require "test_helper"

class ActiveRecordStoreTest < ActiveSupport::TestCase
  ActiveRecordStore = Wonkavision::Analytics::Persistence::ActiveRecordStore

  context "ActiveRecordStore" do
    setup do
      @store = ActiveRecordStore.new(RevenueAnalytics)
    end

    # should "provide access to the underlying facts specification" do
    #   assert_equal @facts, @store.owner
    # end

    context "querying" do
      setup do
      end
      context "#create_sql_query" do
        setup do
          @query = Wonkavision::Analytics::Query.new
          @query.from(:transport)
          @query.columns :account_age_from_dos
          @query.rows :primary_payer_type, :primary_payer
          @query.measures :current_balance
          @query.where :division => 1, :provider.caption => 'REACH', :measures.current_balance.gt => 0
          @sql = @store.send(:create_sql_query, @query, @store.schema.cubes[@query.from])
        end
        should "select from the fact table" do
          assert_equal "fact_transport", @sql.froms[0].name
        end
        context "projections" do
          setup do
            #arel 4 has a projections property, but 3.0 doesn't
            @projections = @sql.instance_eval('@ctx').projections
            #arel 4 has a criteria property, but 3.0 doesn't
            @wheres = @sql.instance_eval('@ctx').wheres
          end
          should "project selected dimension keys and names" do
            selected_keys = @projections.select{|n|n.is_a?(Arel::Nodes::As)}
            assert_equal 6, selected_keys.length
            assert selected_keys.detect{|n|n.right == "account_age_from_dos_key"}, "no age key"
            assert selected_keys.detect{|n|n.right == "account_age_from_dos_caption"}, "no age name"  
            assert selected_keys.detect{|n|n.right == "primary_payer_type_key"}, "no payer type key" 
            assert selected_keys.detect{|n|n.right == "primary_payer_type_caption"}, "no payer type name"  
            assert selected_keys.detect{|n|n.right == "primary_payer_key"}, "no payer key" 
            assert selected_keys.detect{|n|n.right == "primary_payer_caption"}, "no payer name"          
          end
          should "project measures" do
            selected_measures = @projections.select{|n|!n.is_a?(Arel::Nodes::As)}
            assert selected_measures.detect{|m|m.is_a?(Arel::Nodes::Sum) && m.expressions[0].name.to_s == "current_balance" && m.alias == "current_balance_sum"}, "sum"
            assert selected_measures.detect{|m|m.is_a?(Arel::Nodes::Count) && m.expressions[0].name.to_s == "current_balance" && m.alias == "current_balance_count"}, "count"
            assert selected_measures.detect{|m|m.is_a?(Arel::Nodes::Min) && m.expressions[0].name.to_s == "current_balance" && m.alias == "current_balance_min"}, "min"
            assert selected_measures.detect{|m|m.is_a?(Arel::Nodes::Max) && m.expressions[0].name.to_s == "current_balance" && m.alias == "current_balance_max"}, "max"
          end
          should "project sorts" do
            selected_sorts = @projections.select{|n|n.is_a?(Arel::Nodes::Min) && n.alias =~ /.*_sort/ }
            assert selected_sorts.detect{|s|s.alias == "primary_payer_sort"}, "primary_payer"
            assert selected_sorts.detect{|s|s.alias == "account_age_from_dos_sort"}, "account age"
          end
          should "join selected dimensions" do
            assert @sql.join_sources.detect{|join|join.left.left.name.to_s == "dim_aging_category" && join.left.right.to_s == "account_age_from_dos"}, "account age"
            assert @sql.join_sources.detect{|join|join.left.left.name.to_s == "dim_payer" && join.left.right.to_s == "primary_payer_type"}, "primary_payer_type"
            assert @sql.join_sources.detect{|join|join.left.left.name.to_s == "dim_payer" && join.left.right.to_s == "primary_payer"}, "primary_payer"
          end
          should "join slicer dimensions" do
            assert @sql.join_sources.detect{|join|join.left.left.name.to_s == "dim_division" && join.left.right.to_s == "division"}, "division"
            assert @sql.join_sources.detect{|join|join.left.left.name.to_s == "dim_provider" && join.left.right.to_s == "provider"}, "provider"
          end
          should "filter dimensions" do
            assert @wheres.detect{|w|w.is_a?(Arel::Nodes::Equality) && w.left.name.to_s == "division_key" && w.right == 1}
            assert @wheres.detect{|w|w.is_a?(Arel::Nodes::Equality) && w.left.name.to_s == "provider_name" && w.right == 'REACH'}
            assert @wheres.detect{|w|w.is_a?(Arel::Nodes::GreaterThan) && w.left.name.to_s == "current_balance" && w.right == 0}
          end
        end
        
      end

    end

  end
end