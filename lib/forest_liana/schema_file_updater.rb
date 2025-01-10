require_relative 'json_printer'

module ForestLiana
  class SchemaFileUpdater
    include JsonPrinter

    # TODO: Remove nameOld attribute once the lianas versions older than 2.0.0 are minority.
    KEYS_COLLECTION = [
      'name',
      'name_old',
      'icon',
      'integration',
      'is_read_only',
      'is_searchable',
      'is_virtual',
      'only_for_relationships',
      'pagination_type',
      'fields',
      'segments',
      'actions',
    ]
    KEYS_COLLECTION_FIELD = [
      'field',
      'type',
      'default_value',
      'enums',
      'integration',
      'is_filterable',
      'is_read_only',
      'is_required',
      'is_sortable',
      'is_virtual',
      'reference',
      'inverse_of',
      'relationship',
      'widget',
      'validations',
      'polymorphic_referenced_models',
    ]
    KEYS_VALIDATION = [
      'message',
      'type',
      'value',
    ]
    KEYS_ACTION = [
      'name',
      'type',
      'base_url',
      'endpoint',
      'http_method',
      'redirect',
      'download',
      'fields',
      'hooks',
      'description',
      'submit_button_label',
    ]
    KEYS_ACTION_FIELD = [
      'field',
      'type',
      'default_value',
      'enums',
      'is_required',
      'is_read_only',
      'reference',
      'description',
      'position',
      'widget',
      'hook',
    ]
    KEYS_SEGMENT = ['name']

    def initialize filename, collections, meta
      @filename = filename
      @meta = meta

      # NOTICE: Remove unecessary keys
      @collections = collections.map do |collection|
        collection['fields'] = collection['fields'].map do |field|
          unless field['validations'].nil?
            field['validations'] = field['validations'].map { |validation| validation.slice(*KEYS_VALIDATION) }
          end

          field['type'] = 'String' unless field.has_key?('type')
          field['default_value'] = nil unless field.has_key?('default_value')
          field['enums'] = nil unless field.has_key?('enums')
          field['integration'] = nil unless field.has_key?('integration')
          field['is_filterable'] = false unless field.has_key?('is_filterable')
          field['is_read_only'] = true unless field.has_key?('is_read_only')
          field['is_required'] = false unless field.has_key?('is_required')
          field['is_sortable'] = false unless field.has_key?('is_sortable')
          field['is_virtual'] = false unless field.has_key?('is_virtual')
          field['reference'] = nil unless field.has_key?('reference')
          field['inverse_of'] = nil unless field.has_key?('inverse_of')
          field['relationships'] = nil unless field.has_key?('relationships')
          field['widget'] = nil unless field.has_key?('widget')
          field['validations'] = [] unless field.has_key?('validations')

          field.slice(*KEYS_COLLECTION_FIELD)
        end

        collection['actions'] = collection['actions'].map do |action|
          begin
            SmartActionFieldValidator.validate_smart_action_fields(action['fields'], action['name'], action['hooks']['change'])
          rescue ForestLiana::Errors::SmartActionInvalidFieldError => invalid_field_error
            FOREST_LOGGER.warn invalid_field_error.message
          rescue ForestLiana::Errors::SmartActionInvalidFieldHookError => invalid_hook_error
            FOREST_REPORTER.report invalid_hook_error
            FOREST_LOGGER.error invalid_hook_error.message
          end
          action['fields'] = action['fields'].map { |field| field.slice(*KEYS_ACTION_FIELD) }
          action.slice(*KEYS_ACTION)
        end

        collection['segments'] = collection['segments'].map do |segment|
          segment.slice(*KEYS_SEGMENT)
        end

        collection.slice(*KEYS_COLLECTION)
      end

      # NOTICE: Sort keys
      @collections = @collections.map do |collection|
        collection['fields'].sort! do |field1, field2|
          [field1['field'], field1['type'].inspect] <=> [field2['field'], field2['type'].inspect]
        end

        collection['fields'] = collection['fields'].map do |field|
          unless field['validations'].nil?
            field['validations'] = field['validations'].map do |validation|
              validation.sort_by { |key, value| KEYS_VALIDATION.index key }.to_h
            end
          end
          field.sort_by { |key, value| KEYS_COLLECTION_FIELD.index key }.to_h
        end
        collection['actions'] = collection['actions'].map do |action|
          action.sort_by { |key, value| KEYS_ACTION.index key }.to_h
        end
        collection.sort_by { |key, value| KEYS_COLLECTION.index key }.to_h
      end

      @collections.sort! { |collection1, collection2| collection1['name'] <=> collection2['name'] }
    end

    def perform
      File.open(@filename, 'w') do |file|
        # NOTICE: Escape '\' characters to ensure the generation of valid JSON files. It fixes
        #         potential issues if some fields have validations using complex regexp.
        file.puts pretty_print({
          collections: @collections,
          meta: @meta
        }).gsub(/[^\\](\\)[^\\"]/) { |x| x.gsub($1, "\\\\\\") }
      end
    end
  end
end
