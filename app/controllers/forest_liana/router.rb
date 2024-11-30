class ForestLiana::Router
  def call(env)
    params = env['action_dispatch.request.path_parameters']
    collection_name = params[:collection]
    resource = ForestLiana::SchemaUtils.find_model_from_collection_name(collection_name, true)

    if resource.nil?
      FOREST_LOGGER.error "Routing error: Resource not found for collection #{collection_name}."
      FOREST_LOGGER.error "If this is a Smart Collection, please ensure your Smart Collection routes are defined before the mounted ForestLiana::Engine?"
      ForestLiana::BaseController.action(:route_not_found).call(env)
    else
      begin
        component_prefix = ForestLiana.component_prefix(resource)
        controller_name = "#{component_prefix}Controller"

        controller = "ForestLiana::UserSpace::#{controller_name}".constantize
        action = nil

        case env['REQUEST_METHOD']
        when 'GET'
          if params[:id]
            action = 'show'
          elsif env['PATH_INFO'] == "/#{collection_name}/count"
            action = 'count'
          else
            action = 'index'
          end
        when 'PUT'
          action = 'update'
        when 'POST'
          action = 'create'
        when 'DELETE'
          if params[:id]
            action = 'destroy'
          else
            action = 'destroy_bulk'
          end
        end

        params["action"] = action
        params["controller"] = "#{env["SCRIPT_NAME"]}/#{collection_name}".delete_prefix("/")
        controller.action(action.to_sym).call(env)
      rescue NoMethodError => exception
        FOREST_REPORTER.report exception
        FOREST_LOGGER.error "Routing error: #{exception}\n#{exception.backtrace.join("\n\t")}"
        ForestLiana::BaseController.action(:route_not_found).call(env)
      end
    end
  end
end
