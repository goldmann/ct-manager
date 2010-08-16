require 'ct-agent/helpers/config-helper'
require 'ct-agent/helpers/log-helper'

class ServiceManager
  class << self
    def prepare( config, log )
      @config  = config
      @log     = log

      @service_classes = []
      @services = {}

      Dir["lib/ct-agent/services/**/*.rb"].each {|file| require file }

      load_services
    end

    def load_services
      @log.info "Loading services..."

      @service_classes.each do |clazz|
        @log.debug "Loading #{clazz} service..."
        o = clazz.new
        o.send(:prepare, :log => @log )
        @log.debug "Service #{clazz} loaded."
      end

      @log.info "#{@service_classes.size} service(s) loaded."
    end

    def register_service( o, name, full_name )
      if @config['services'].include?( name.to_s )
        @log.debug "Registering #{o.class} service..."
        @services[name] = { :object => o, :info => { :name => name, :full_name => full_name } }

        return Service.create( :name => name )
      else
        @log.warn "Service already registered!"
      end

      nil
    end

    def register_service_class( clazz )
      @service_classes << clazz
    end

    def services_info
      info = []

      @services.values.each do |service|
        info << service[:info]
      end

      info
    end

    def execute_operation( name, operation, *params )
      service = @services[name.to_sym][:object]

      unless service.respond_to?( operation )
        return { :operation => operation, :status => 'error', :message => "Operation '#{operation}' is not supported in #{service.class} service"}
      end

      if service.method( operation ).arity != params.size and service.method( operation ).arity >= 0
        return { :operation => operation, :status => 'error', :message => "Operation '#{operation}' takes #{service.method( operation ).arity } argument, but provided #{params.size}"}
      end

      @log.debug "Executing #{operation} operation for #{service.class}..."

      service.send( operation, *params )
    end

    def service_exists?( name )
      !@services[name.to_sym].nil?
    end
  end

  #attr_reader :services
end

