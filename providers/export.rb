#
# Cookbook Name:: nfs
# Providers:: export
#
# Copyright 2012, Riot Games
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

action :create do

  cached_new_resource = new_resource
  cached_new_resource = current_resource

  sub_run_context = @run_context.dup
  sub_run_context.resource_collection = Chef::ResourceCollection.new

  begin
    original_run_context, @run_context = @run_context, sub_run_context

    execute_exportfs
    export_pattern = get_export_pattern(new_resource)
    export_line = get_export_line(new_resource)

    if ::File.zero? '/etc/exports' or not ::File.exists? '/etc/exports'
      file '/etc/exports' do
        content export_line
        notifies :run, "execute[exportfs]", :immediately
      end
    else
      replace_or_add "export #{new_resource.name}" do
        path "/etc/exports"
        pattern export_pattern
        line export_line
        notifies :run, "execute[exportfs]", :immediately
      end
    end
  ensure
    @run_context = original_run_context
  end

  # converge
  begin
    Chef::Runner.new(sub_run_context).converge
  ensure
    if sub_run_context.resource_collection.any?(&:updated?)
      new_resource.updated_by_last_action(true)
    end
  end

end

action :delete do

  cached_new_resource = new_resource
  cached_new_resource = current_resource

  sub_run_context = @run_context.dup
  sub_run_context.resource_collection = Chef::ResourceCollection.new

  begin
    original_run_context, @run_context = @run_context, sub_run_context

    if ::File.exists? '/etc/exports'
      execute_exportfs
      export_pattern = get_export_pattern(new_resource)

      delete_lines "un-export #{new_resource.name}" do
        path "/etc/exports"
        pattern export_pattern
        notifies :run, "execute[exportfs]", :immediately
      end
    end
  ensure
    @run_context = original_run_context
  end

  # converge
  begin
    Chef::Runner.new(sub_run_context).converge
  ensure
    if sub_run_context.resource_collection.any?(&:updated?)
      new_resource.updated_by_last_action(true)
    end
  end

end

private

# Gets the export line for the given resource
#
# @param [Resource] nfs::export resource
# @return [String] the export line
def get_export_line(resource)
  ro_rw = resource.writeable ? "rw" : "ro"
  sync_async = resource.sync ? "sync" : "async"
  if resource.anonuser
    resource.options << "anonuid=#{find_uid(resource.anonuser)}"
  end
  if resource.anongroup
    resource.options << "anongid=#{find_gid(resource.anongroup)}"
  end
  options = resource.options.join(',')
  options = ",#{options}" unless options.empty?

  "#{resource.directory} #{resource.network}(#{ro_rw},#{sync_async}#{options})"
end

# Gets the pattern to replace the given resource's export line
#
# This will not match export lines with multiple networks!
#
# @param [Resource] nfs::export resource
# @return [String] the pattern for matching the resource's export line
def get_export_pattern(resource)
  "^#{resource.directory} #{resource.network}[\\\(\\\n]"
end

# Creates a dormant execute resource to update system exports
def execute_exportfs()
  execute "exportfs" do
    command "exportfs -ar"
    action :nothing
  end
end

# Finds the UID for the given user name
#
# @param [String] username
# @return
def find_uid(username)
  uid = nil
  Etc.passwd do |entry|
    if entry.name == username
      uid = entry.uid
      break
    end
  end
  uid
end

# Finds the GID for the given group name
#
# @param [String] groupname
# @return [Integer] the matching GID or nil
def find_gid(groupname)
  gid = nil
  Etc.group do |entry|
    if entry.name == groupname
      gid = entry.gid
      break
    end
  end
  gid
end
