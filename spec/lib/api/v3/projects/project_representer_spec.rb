#-- copyright
# OpenProject is a project management system.
# Copyright (C) 2012-2018 the OpenProject Foundation (OPF)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2017 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See docs/COPYRIGHT.rdoc for more details.
#++

require 'spec_helper'

describe ::API::V3::Projects::ProjectRepresenter do
  include ::API::V3::Utilities::PathHelper

  let(:project) { FactoryBot.build_stubbed(:project) }
  let(:representer) { described_class.new(project, current_user: user) }
  let(:user) do
    FactoryBot.build_stubbed(:user)
  end
  let(:permissions) { [:add_work_packages] }

  before do
    allow(user)
      .to receive(:allowed_to?)
      .and_return(false)

    permissions.each do |permission|
      allow(user)
        .to receive(:allowed_to?)
        .with(permission, project)
        .and_return(true)
    end
  end

  context 'generation' do
    subject(:generated) { representer.to_json }

    it { is_expected.to include_json('Project'.to_json).at_path('_type') }

    describe 'project' do
      it { is_expected.to have_json_path('id') }
      it { is_expected.to have_json_path('identifier') }
      it { is_expected.to have_json_path('name') }
      it { is_expected.to have_json_path('description') }

      it_behaves_like 'has UTC ISO 8601 date and time' do
        let(:date) { project.created_on }
        let(:json_path) { 'createdAt' }
      end

      it_behaves_like 'has UTC ISO 8601 date and time' do
        let(:date) { project.updated_on }
        let(:json_path) { 'updatedAt' }
      end
    end

    describe '_links' do
      it { is_expected.to have_json_type(Object).at_path('_links') }
      it 'should link to self' do
        expect(subject).to have_json_path('_links/self/href')
      end
      it 'should have a title for link to self' do
        expect(subject).to have_json_path('_links/self/title')
      end

      describe 'create work packages' do
        context 'user allowed to create work packages' do
          it 'has the correct path for a create form' do
            is_expected
              .to be_json_eql(api_v3_paths.create_project_work_package_form(project.id).to_json)
              .at_path('_links/createWorkPackage/href')
          end

          it 'has the correct path to create a work package' do
            is_expected.to be_json_eql(api_v3_paths.work_packages_by_project(project.id).to_json)
              .at_path('_links/createWorkPackageImmediate/href')
          end
        end

        context 'user not allowed to create work packages' do
          let(:permissions) { [] }

          it { is_expected.to_not have_json_path('_links/createWorkPackage/href') }

          it { is_expected.to_not have_json_path('_links/createWorkPackageImmediate/href') }
        end
      end

      describe 'categories' do
        it 'has the correct link to its categories' do
          is_expected.to be_json_eql(api_v3_paths.categories_by_project(project.id).to_json)
            .at_path('_links/categories/href')
        end
      end

      describe 'versions' do
        it 'has the correct link to its versions' do
          is_expected.to be_json_eql(api_v3_paths.versions_by_project(project.id).to_json)
            .at_path('_links/versions/href')
        end
      end

      describe 'types' do
        context 'for a user having the view_work_packages permission' do
          let(:permissions) { [:view_work_packages] }

          it 'links to the types active in the project' do
            is_expected.to be_json_eql(api_v3_paths.types_by_project(project.id).to_json)
              .at_path('_links/types/href')
          end

          it 'links to the work packages in the project' do
            is_expected.to be_json_eql(api_v3_paths.work_packages_by_project(project.id).to_json)
                             .at_path('_links/workPackages/href')
          end
        end

        context 'for a user having the manage_types permission' do
          let(:permissions) { [:manage_types] }

          it 'links to the types active in the project' do
            is_expected.to be_json_eql(api_v3_paths.types_by_project(project.id).to_json)
                             .at_path('_links/types/href')
          end
        end

        context 'for a user not having the necessary permissions' do
          let(:permission) { [] }

          it 'has no types link' do
            is_expected.to_not have_json_path('_links/types/href')
          end

          it 'has no work packages link' do
            is_expected.to_not have_json_path('_links/workPackages/href')
          end
        end
      end
    end

    describe 'caching' do
      it 'is based on the representer\'s cache_key' do
        expect(OpenProject::Cache)
          .to receive(:fetch)
          .with(representer.json_cache_key)
          .and_call_original

        representer.to_json
      end

      describe '#json_cache_key' do
        let!(:former_cache_key) { representer.json_cache_key }

        it 'includes the name of the representer class' do
          expect(representer.json_cache_key)
            .to include('API', 'V3', 'Projects', 'ProjectRepresenter')
        end

        it 'changes when the locale changes' do
          I18n.with_locale(:fr) do
            expect(representer.json_cache_key)
              .not_to eql former_cache_key
          end
        end

        it 'changes when the project is updated' do
          project.updated_on = Time.now + 20.seconds

          expect(representer.json_cache_key)
            .not_to eql former_cache_key
        end
      end
    end
  end

  describe '.checked_permissions' do
    it 'lists add_work_packages' do
      expect(described_class.checked_permissions).to match_array([:add_work_packages])
    end
  end
end
