module ForestLiana
  class ResourcesGetter < BaseGetter
    attr_reader :search_query_builder
    attr_reader :includes
    attr_reader :records_count

    def initialize(resource, params)
      @resource = resource
      @params = params
      @count_needs_includes = false
      @collection_name = ForestLiana.name_for(@resource)
      @collection = get_collection(@collection_name)
      @fields_to_serialize = get_fields_to_serialize
      @field_names_requested = field_names_requested
      get_segment()
      compute_includes()
      @search_query_builder = SearchQueryBuilder.new(@params, @includes, @collection)

      prepare_query()
    end

    def self.get_ids_from_request(params)
      attributes = params.dig('data', 'attributes')
      has_body_attributes = attributes != nil
      is_select_all_records_query = has_body_attributes && attributes[:all_records] === true
    
    
      # NOTICE: If it is not a "select all records" query and it receives a list of ID.
      if (!is_select_all_records_query && attributes[:ids])
        return attributes[:ids]
      end
    
      collection_name = attributes[:collection_name]
      model = ForestLiana::SchemaUtils.find_model_from_collection_name(collection_name)
      resources_getter = ForestLiana::ResourcesGetter.new(model, attributes)
      resources = Array.new
      resources_getter.query_for_batch.find_in_batches() do |records|
        resources += records.map { |record| record.id }
      end
      return resources
    end

    def perform
      @records = @records.eager_load(@includes)
    end

    def count
      # NOTICE: For performance reasons, do not eager load the data if there is  no search or
      #         filters on associations.
      @records_count = @count_needs_includes ? @records.eager_load(@includes).count : @records.count
    end

    def query_for_batch
      @records
    end

    def records
      @records.offset(offset).limit(limit).to_a
    end

    def compute_includes
      associations_has_one = ForestLiana::QueryHelper.get_one_associations(@resource)

      includes = associations_has_one.map(&:name)
      includes_for_smart_search = []

      if @collection && @collection.search_fields
        includes_for_smart_search = @collection.search_fields
          .select { |field| field.include? '.' }
          .map { |field| field.split('.').first.to_sym }

        includes_has_many = SchemaUtils.many_associations(@resource)
          .select { |association| SchemaUtils.model_included?(association.klass) }
          .map(&:name)

        includes_for_smart_search = includes_for_smart_search & includes_has_many
      end

      if @field_names_requested
        @includes = (includes & @field_names_requested).concat(includes_for_smart_search)
      else
        @includes = includes
      end
    end

    def includes_for_serialization
      super & @fields_to_serialize.map(&:to_s)
    end

    private

    def get_fields_to_serialize
      if @params[:fields] && @params[:fields][@collection_name]
        @params[:fields][@collection_name].split(',').map { |name| name.to_sym }
      else
        []
      end
    end

    def get_segment
      if @params[:segment]
        @segment = @collection.segments.find do |segment|
          segment.name == @params[:segment]
        end
      end
      @segment ||= nil
    end

    def field_names_requested
      return nil unless @params[:fields] && @params[:fields][@collection_name]

      associations_for_query = []

      # NOTICE: Populate the necessary associations for filters
      if @params[:filter]
        @params[:filter].each do |field, values|
          if field.include? ':'
            associations_for_query << field.split(':').first.to_sym
            @count_needs_includes = true
          end
        end
      end

      @count_needs_includes = true if @params[:search]

      if @params[:sort] && @params[:sort].include?('.')
        associations_for_query << @params[:sort].split('.').first.to_sym
      end

      @fields_to_serialize | associations_for_query
    end

    def search_query
      @search_query_builder.perform(@records)
    end

    def prepare_query
      @records = get_resource

      if @segment && @segment.scope
        @records = @records.send(@segment.scope)
      elsif @segment && @segment.where
        @records = @records.where(@segment.where.call())
      end

      # NOTICE: Live Query mode
      if @params[:segmentQuery]
        LiveQueryChecker.new(@params[:segmentQuery], 'Live Query Segment').validate()

        begin
          segmentQuery = @params[:segmentQuery].gsub(/\;\s*$/, '')
          @records = @records.where(
            "#{@resource.table_name}.#{@resource.primary_key} IN (SELECT id FROM (#{segmentQuery}) as ids)"
          )
        rescue => error
          error_message = "Live Query Segment: #{error.message}"
          FOREST_LOGGER.error(error_message)
          raise ForestLiana::Errors::LiveQueryError.new(error_message)
        end
      end

      @records = search_query
    end

    def association?(field)
      @resource.reflect_on_association(field.to_sym).present?
    end

    def offset
      return 0 unless pagination?

      number = @params[:page][:number]
      if number && number.to_i > 0
        (number.to_i - 1) * limit
      else
        0
      end
    end

    def limit
      return 10 unless pagination?

      if @params[:page][:size]
        @params[:page][:size].to_i
      else
        10
      end
    end

    def pagination?
      @params[:page] && @params[:page][:number]
    end

  end
end
