require "config"
require "nats"
require 'socket'

module Collector
    class Collector
        def initialize(config_path)
            @config=Config.new(config_path).config
            @sids={}
            @nats=nil
            @local_ip=nil
        end
        attr_reader :config
        attr_reader :nats
        def setup_nats
            @nats = Nats.new(config['message_bus_uri'])
        end
        def run
            register_to_master
            sub_task
        end
        def get_ip
            @local_ip||IPSocket.getaddress(Socket.gethostname)
        end
        def register_to_master
            EM::PeriodicTimer.new(1) do  
                data={:ip=>get_ip}
                nats.publish("collector_register",data)
            end
        end
        def sub_task
            nats.subscribe("collector_task_#{get_ip}") do |message|
                clear_collect
                collect(message)
            end
        end
        def clear_collect
            @sids.each { |_, sid| nats.unsubscribe(sid) }
            @sids = {}
        end
        def collect(message) 
            range=message[:range]
            range.each do |i|
                sid=nats.subscribe("jpaas_collector_#{i}") do |message|
                    process_message(message)
                end
                @sids["jpaas_collector_#{i}"]=sid
            end
        end
        def process_message(message)
            p message
        end
    end
end
