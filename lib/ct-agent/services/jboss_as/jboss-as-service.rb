# JBoss, Home of Professional Open Source
# Copyright 2009, Red Hat Middleware LLC, and individual contributors
# by the @authors tag. See the copyright.txt in the distribution for a
# full listing of individual contributors.
#
# This is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation; either version 2.1 of
# the License, or (at your option) any later version.
#
# This software is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this software; if not, write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
# 02110-1301 USA, or see the FSF site: http://www.fsf.org.

require 'ct-agent/services/jboss_as/commands/update-s3ping-credentials-command'
require 'ct-agent/services/jboss_as/commands/update-gossip-host-address-command'
require 'ct-agent/services/jboss_as/commands/update-proxy-list-command'
require 'ct-agent/services/commands/restart-command'
require 'ct-agent/services/commands/start-command'
require 'ct-agent/services/commands/stop-command'
require 'ct-agent/services/jboss_as/commands/configure-command'
require 'ct-agent/managers/service-manager'
require 'json'

module CoolingTower
  class JBossASService

    JBOSS_AS_SYSCONFIG_FILE = '/etc/sysconfig/jboss-as'
    JBOSS_AS_HOME           = '/opt/jboss-as'

    attr_accessor :state

    attr_reader :db
    attr_reader :name

    def initialize( options = {} )
      @db = ServiceManager.register( self, 'JBoss Application Server' )

      @log            = options[:log]             || Logger.new(STDOUT)
      @exec_helper    = options[:exec_helper]     || ExecHelper.new( :log => @log )

      @jboss_config_file      = '/etc/sysconfig/jboss-as'
      @default_configuration  = 'default'
      @name                   = 'jboss-as6'

      # TODO should we also include :error status?
      @state                  = :stopped # available statuses: :starting, :started, :configuring, :stopping, :stopped
    end

    def restart
      RestartCommand.new( self, :log => @log, :threaded => true ).execute
    end

    def start
      StartCommand.new( self, :log => @log, :threaded => true ).execute
    end

    def stop
      StopCommand.new( self, :log => @log, :threaded => true ).execute
    end

    def configure( data )
      ConfigureCommand.new( self, :log => @log, :threaded => true  ).execute( data )
    end

    def status
      { :status => 'ok', :response => { :state => @state } }
    end

    def artifacts

      artifacts = []

      @db.artifacts.each do |artifact|
        artifacts << { :name => artifact.name, :id => artifact.id }
      end

      { :status => 'ok', :response => artifacts }
    end

    def deploy( artifact )
      @db.save_event( :deploy, :received )

      #TODO base 64 decode artifact
      # validate the parameter, do the job, etc
      # Tempfile
      # FileUtils.cp( tempfile, "#{JBOSS_AS_HOME}/server/#{@default_configuration}/deploy/" )

      name = 'abc.war'

      if a = @db.save_artifact( :name => name, :location => "#{JBOSS_AS_HOME}/server/#{@default_configuration}/deploy/#{name}" )
        @db.save_event( :deploy, :finished )
        { :status => 'ok', :response => { :artifact_id => a.id } }
      else
        @db.save_event( :deploy, :failed )
        { :status => 'error', :msg => "Error while saving artifact" }
      end
    end

    def undeploy( artifact_id )
      @db.save_event( :undeploy, :received )

      # TODO: remove artifact from JBoss

      if @db.remove_artifact( artifact_id )
        @db.save_event( :undeploy, :finished )
        { :status => 'ok' }
      else
        @db.save_event( :undeploy, :failed )
        { :status => 'error', :msg => "Error occurred while removing artifact with id = '#{artifact_id}'" }
      end
    end
  end
end