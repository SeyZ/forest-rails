module ForestLiana
  class ResourcesController < ForestLiana::ApplicationController
    begin
      prepend ResourcesExtensions
    rescue NameError
    end

    rescue_from ActiveRecord::RecordNotFound, :with => :record_not_found

    if Rails::VERSION::MAJOR < 4
      before_filter :find_resource
    else
      before_action :find_resource
    end

    def index
      getter = ForestLiana::ResourcesGetter.new(@resource, params)
      getter.perform

      respond_to do |format|
        format.json { render_jsonapi(getter) }
        format.csv { render_csv(getter, @resource) }
      end
    end

    def show
      getter = ForestLiana::ResourceGetter.new(@resource, params)
      getter.perform

      render serializer: nil, json:
        serialize_model(get_record(getter.record), include: includes(getter))
    end

    def create
      creator = ForestLiana::ResourceCreator.new(@resource, params)
      creator.perform

      if creator.errors
        render serializer: nil, json: JSONAPI::Serializer.serialize_errors(
          creator.errors), status: 400
      elsif creator.record.valid?
        render serializer: nil,
          json: serialize_model(get_record(creator.record), include: record_includes)
      else
        render serializer: nil, json: JSONAPI::Serializer.serialize_errors(
          creator.record.errors), status: 400
      end
    end

    def update
      updater = ForestLiana::ResourceUpdater.new(@resource, params)
      updater.perform

      if updater.errors
        render serializer: nil, json: JSONAPI::Serializer.serialize_errors(
          updater.errors), status: 400
      elsif updater.record.valid?
        render serializer: nil,
          json: serialize_model(get_record(updater.record), include: record_includes)
      else
        render serializer: nil, json: JSONAPI::Serializer.serialize_errors(
          updater.record.errors), status: 400
      end
    end

    def destroy
      @resource.destroy(params[:id])
      head :no_content
    end

    private

    def find_resource
      @resource = SchemaUtils.find_model_from_collection_name(params[:collection])

      if @resource.nil? || !SchemaUtils.model_included?(@resource) ||
          !@resource.ancestors.include?(ActiveRecord::Base)
        render serializer: nil, json: {status: 404}, status: :not_found
      end
    end

    def includes(getter)
      getter.includes.map(&:to_s)
    end

    def record_includes
      SchemaUtils.one_associations(@resource)
        .select { |a| SchemaUtils.model_included?(a.klass) }
        .map { |a| a.name.to_s }
    end

    def record_not_found
      head :not_found
    end

    def is_sti_model?
      @is_sti_model ||= (@resource.inheritance_column.present? &&
        @resource.columns.any? { |column| column.name == @resource.inheritance_column })
    end

    def get_record record
      is_sti_model? ? record.becomes(@resource) : record
    end

    def render_jsonapi getter
      records = getter.records.map { |record| get_record(record) }
      fields = params[:fields].to_unsafe_h()
      models_fields_filter = fields_params_to_filter(fields, @resource)

      json = serialize_models(
        records,
        include: includes(getter),
        fields: models_fields_filter,
        count: getter.count,
        params: params
      )

      render serializer: nil, json: json
    end
  end
end
