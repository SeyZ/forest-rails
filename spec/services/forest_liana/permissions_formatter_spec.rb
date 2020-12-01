module ForestLiana
  describe PermissionsFormatter do
    describe '#convert_to_new_format' do
      let(:old_format_collection_permissions) {
        {
          'list'=>false,
          'show'=>false,
          'create'=>false,
          'update'=>false,
          'delete'=>false,
          'export'=>false,
          'searchToEdit'=>true
        }
      }
      let(:old_format_action_permissions) { { 'allowed' => true, 'users' => nil } }
      let(:old_format_permissions) {
        {
          'collection_1' => {
            'collection' => old_format_collection_permissions,
            'actions' => {
              'action_1' => old_format_action_permissions
            },
            'scope' => nil
          }
        }
      }

      let(:converted_permission) { described_class.convert_to_new_format(old_format_permissions) }

      describe 'collection permissions' do
        subject { converted_permission['collection_1']['collection'] }

        let(:expected_new_collection_permissions_format) {
          {
            'browseEnabled'=>true,
            'readEnabled'=>false,
            'addEnabled'=>false,
            'editEnabled'=>false,
            'deleteEnabled'=>false,
            'exportEnabled'=>false
          }
        }

        it 'should convert the old format to the new one' do
          expect(subject).to eq expected_new_collection_permissions_format
        end
      end

      describe 'action permissions' do
        subject { converted_permission['collection_1']['actions']['action_1'] }

        context 'when allowed is true' do
          context 'when users is nil' do
            let(:old_format_action_permissions) { { 'allowed' => true, 'users' => nil } }
            let(:expected_new_action_permissions_format) { { 'triggerEnabled' => true } }

            it 'expected action permission triggerEnabled field should be true' do
              expect(subject).to eq expected_new_action_permissions_format
            end
          end

          context 'when users is an empty array' do
            let(:old_format_action_permissions) { { 'allowed' => true, 'users' => [] } }
            let(:expected_new_action_permissions_format) { { 'triggerEnabled' => [] } }

            it 'expected action permission triggerEnabled field should be an empty array' do
              expect(subject).to eq expected_new_action_permissions_format
            end
          end

          context 'when users is NOT an empty array' do
            let(:old_format_action_permissions) { { 'allowed' => true, 'users' => [2, 3] } }
            let(:expected_new_action_permissions_format) { { 'triggerEnabled' => [2, 3] } }

            it 'expected action permission triggerEnabled field should be equal to the users array' do
              expect(subject).to eq expected_new_action_permissions_format
            end
          end
        end

        context 'when allowed is false' do
          context 'when users is nil' do
            let(:old_format_action_permissions) { { 'allowed' => false, 'users' => nil } }
            let(:expected_new_action_permissions_format) { { 'triggerEnabled' => false } }

            it 'expected action permission triggerEnabled field should be false' do
              expect(subject).to eq expected_new_action_permissions_format
            end
          end

          context 'when users is an empty array' do
            let(:old_format_action_permissions) { { 'allowed' => false, 'users' => [] } }
            let(:expected_new_action_permissions_format) { { 'triggerEnabled' => false } }

            it 'expected action permission triggerEnabled field should be false' do
              expect(subject).to eq expected_new_action_permissions_format
            end
          end

          context 'when users is NOT an empty array' do
            let(:old_format_action_permissions) { { 'allowed' => false, 'users' => [2, 3] } }
            let(:expected_new_action_permissions_format) { { 'triggerEnabled' => false } }

            it 'expected action permission triggerEnabled field should be false' do
              expect(subject).to eq expected_new_action_permissions_format
            end
          end
        end
      end
    end
  end
end
