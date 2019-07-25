module ForestLiana
  class ValueStatGetter < StatGetter
    attr_accessor :record

    def perform
      return if @params[:aggregate].blank?
      resource = current_value = get_resource().eager_load(@includes)

      if @params[:filters]
        filter_parser = FiltersParser.new(@params[:filters], resource, @params[:timezone])
        current_value = filter_parser.apply_filters
        raw_previous_interval = filter_parser.get_previous_interval_condition

        if raw_previous_interval
          previous_value = filter_parser.apply_filters_on_previous_interval(raw_previous_interval)
        end
      end

      @record = Model::Stat.new(value: {
        countCurrent: count(current_value),
        countPrevious: previous_value ? count(previous_value) : nil
      })
    end

    private

    def count(value)
      uniq = @params[:aggregate].downcase == 'count'

      if Rails::VERSION::MAJOR >= 4
        if uniq
          # NOTICE: uniq is deprecated since Rails 5.0
          value = Rails::VERSION::MAJOR >= 5 ? value.distinct : value.uniq
        end
        value.send(@params[:aggregate].downcase, aggregate_field)
      else
        value.send(@params[:aggregate].downcase, aggregate_field, distinct: uniq)
      end
    end

    def aggregate_field
      @params[:aggregate_field] || @resource.primary_key
    end

  end
end
