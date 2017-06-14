module ForestLiana
  class ResourceUpdaterTest < ActiveSupport::TestCase

    collection = ForestLiana::Model::Collection.new({
      name: 'serialize_fields',
      fields: [{
        type: 'String',
        field: 'field'
      }]
    })

    ForestLiana.apimap << collection
    ForestLiana.models << SerializeField

    test 'attribute null' do
      params = ActionController::Parameters.new(
        id: 1,
        data: {
          id: 1,
          type: "serialize_field",
          attributes: { }
        }
      )
      updater = ResourceUpdater.new(SerializeField, params)
      updater.perform
      assert updater.record.valid?
    end

    test 'right attribute' do
      params = ActionController::Parameters.new(
        id: 1,
        data: {
            id: 1,
            type: "serialize_field",
            attributes: {
              field: "[\"test\", \"test\"]"
            }
          }
      )
      updater = ResourceUpdater.new(SerializeField, params)
      updater.perform
      assert updater.record.valid?
    end
  end
end
