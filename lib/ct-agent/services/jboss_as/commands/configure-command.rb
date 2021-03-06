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

require 'ct-agent/services/jboss_as/commands/update-gossip-host-address-command'
require 'ct-agent/services/jboss_as/commands/update-proxy-list-command'
require 'ct-agent/services/jboss_as/commands/update-s3ping-credentials-command'

module CoolingTower
  class ConfigureCommand
    def initialize( service, options = {})
      @cmds     = {}

      @service        = service
      @state          = @service.state

      @log            = options[:log]             || Logger.new(STDOUT)
      @exec_helper    = options[:exec_helper]     || ExecHelper.new( :log => @log )
      @threaded       = options[:threaded]        || false

      add_command( UpdateGossipHostAddressCommand.new( :log => @log ), :offline )
      add_command( UpdateProxyListCommand.new( :log => @log ), :online )
      add_command( UpdateS3PingCredentialsCommand.new( :log => @log ), :offline )
    end

    def add_command( cmd, type )
      @cmds[type] = [] if @cmds[type].nil?
      @cmds[type] << cmd

      self
    end

    def execute( data )
      event = @service.db.save_event( :configure, :started )

      unless [:started, :stopped].include?( @state )
        msg = "Service is currently in '#{@state}' state. It needs to be in 'started' or 'stopped' state to execute this action."
        @log.error msg
        @service.db.save_event( :configure, :failed, :msg => msg )
        return { :status => 'error', :msg => msg }
      end

      invalid_data = true

      begin
        unless data.nil?
          data = JSON.parse( data, :symbolize_names => true )

          invalid_data = false if data.is_a?(Hash)
        end
      rescue
      end

      if invalid_data
        msg = "No or invalid data provided to configure service."
        @log.error msg
        @service.db.save_event( :configure, :failed, :msg => msg )
        return { :status => 'error', :msg => msg }
      end

      @service.state = :configuring

      if @threaded
        Thread.new { configure( data, event ) }
      else
        configure( data, event )
      end

      { :status => 'ok', :response => { :state => @service.state } }
    end

    def configure( data, event = nil )
      begin
        restart = false

        restart = true if UpdateGossipHostAddressCommand.new( :log => @log ).execute( data[:gossip_host] ) unless data[:gossip_host].nil?
        restart = true if UpdateS3PingCredentialsCommand.new( :log => @log ).execute( data[:s3_ping] ) unless data[:s3_ping].nil?

        restart = false if @state == :stopped

        substate = @state

        unless data[:proxy_list].nil?
          unless @state == :started
            unless @service.service_helper.execute( :start, :event => event, :background => false )[:status] == 'ok'
              msg = "Starting JBoss AS failed, couldn't finish updating JBoss AS"
              @log.error msg
              @service.state = @state
              @service.db.save_event( :configure, :failed, :msg => msg )
              substate = :stopped
              return false
            end

            substate = :started
          end

          restart = true if UpdateProxyListCommand.new( :log => @log ).execute( data[:proxy_list] ) unless data[:proxy_list].nil?
        end

        if restart
          unless @service.service_helper.execute( :restart, :event => event, :background => false )[:status] == 'ok'
            msg = "Restarting JBoss AS failed, couldn't finish updating JBoss AS"
            @log.error msg
            @service.state = @state
            @service.db.save_event( :configure, :failed, :msg => msg )
            substate = :stopped
            return false
          end
        end

        @service.state = substate
        @service.db.save_event( :configure, :finished )
      rescue => e
        msg = "An error occurred while configuring '#{@service.name}' service"
        @log.error e
        @log.error msg
        @service.state = @state
        @service.db.save_event( :configure, :failed, :msg => msg )
        return false
      end
    end
  end
end