test_name 'Test behavior of directory environments when environmentpath is set to a non-existent directory' do
  require 'puppet/acceptance/environment_utils'
  extend Puppet::Acceptance::EnvironmentUtils
  require 'puppet/acceptance/classifier_utils'
  extend Puppet::Acceptance::ClassifierUtils

  tag 'audit:high',
      'audit:unit', # The error responses for the agent should be covered by Ruby unit tests.
      # The server 404/400 response should be covered by server integration tests.
      'server'

  teardown do
    agents.each do |agent|
      on(agent, puppet('config print lastrunfile')) do |command_result|
        agent.rm_rf(command_result.stdout)
      end
    end
  end

  classify_nodes_as_agent_specified_if_classifer_present

  step 'setup environments'

  testdir                = create_tmpdir_for_user(master, 'confdir')
  puppet_conf_backup_dir = create_tmpdir_for_user(master, "puppet-conf-backup-dir")

  apply_manifest_on(master, environment_manifest(testdir), :catch_failures => true)

  step 'Test' do
    env_path    = '/doesnotexist'
    master_opts = {
        'main' => {
            'environmentpath' => "#{env_path}",
        }
    }
    env         = 'testing'

    results = use_an_environment(env, 'bad environmentpath', master_opts, testdir, puppet_conf_backup_dir, :directory_environments => true)

    expectations = {
        :puppet_config           => {
            :exit_code => 0,
            :matches   => [%r{basemodulepath = /etc/puppetlabs/code/modules:/opt/puppetlabs/puppet/modules},
                           %r{modulepath =},
                           %r{manifest =},
                           %r{config_version =}],
        },
        :puppet_apply            => {
            :exit_code => 1,
            :matches   => [%r{Could not find a directory environment named '#{env}' anywhere in the path.*#{env_path}}],
        },
        :puppet_agent            => {
            :exit_code => 0,
        },
    }

    agents.each do |host|
      unless host['locale'] == 'ja'
        expectations[:puppet_agent][:matches] = [%r{Environment '#{env}' not found on server, skipping initial pluginsync.},
                                                 %r{Local environment: '#{env}' doesn't match server specified environment 'production', restarting agent run with environment 'production'}]
      end
    end

    assert_review(review_results(results, expectations))
  end
end
