module ForestLiana
  class StatsController < ForestLiana::ApplicationController
    include ForestLiana::Ability
    if Rails::VERSION::MAJOR < 4
      before_filter do
        find_resource
        check_permission
      end
    else
      before_action do
        find_resource
        check_permission
      end
    end

    CHART_TYPE_VALUE = 'Value'
    CHART_TYPE_PIE = 'Pie'
    CHART_TYPE_LINE = 'Line'
    CHART_TYPE_LEADERBOARD = 'Leaderboard'
    CHART_TYPE_OBJECTIVE = 'Objective'

    def get
      case params[:type]
      when CHART_TYPE_VALUE
        stat = ValueStatGetter.new(@resource, params, forest_user)
      when CHART_TYPE_PIE
        stat = PieStatGetter.new(@resource, params, forest_user)
      when CHART_TYPE_LINE
        stat = LineStatGetter.new(@resource, params, forest_user)
      when CHART_TYPE_OBJECTIVE
        stat = ObjectiveStatGetter.new(@resource, params, forest_user)
      when CHART_TYPE_LEADERBOARD
        stat = LeaderboardStatGetter.new(@resource, params, forest_user)
      end

      stat.perform
      if stat.record
        render json: serialize_model(stat.record), serializer: nil
      else
        render json: {status: 404}, status: :not_found, serializer: nil
      end
    end

    def get_with_live_query
      begin
        stat = QueryStatGetter.new(params)
        stat.perform

        if stat.record
          render json: serialize_model(stat.record), serializer: nil
        else
          render json: {status: 404}, status: :not_found, serializer: nil
        end
      rescue ForestLiana::Errors::LiveQueryError => error
        render json: { errors: [{ status: 422, detail: error.message }] },
          status: :unprocessable_entity, serializer: nil
      rescue => error
        FOREST_REPORTER.report error
        FOREST_LOGGER.error "Live Query error: #{error.message}"
        render json: { errors: [{ status: 422, detail: error.message }] },
          status: :unprocessable_entity, serializer: nil
      end
    end

    def params
      super.permit!
    end

    private

    def find_resource
      @resource = SchemaUtils.find_model_from_collection_name(params[:collection])

      if @resource.nil? || !@resource.ancestors.include?(ActiveRecord::Base)
        render json: {status: 404}, status: :not_found, serializer: nil
      end
    end

    def check_permission
      begin
        forest_authorize!('chart', forest_user, nil, {parameters: params})
      rescue => error
        FOREST_REPORTER.report error
        FOREST_LOGGER.error "Stats execution error: #{error}"
      end
    end
  end
end
