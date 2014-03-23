require "config"
require "nats"
require 'socket'
require "logger"

module Collector
    class Collector
        def initialize(config_path)
            @config=Config.new(config_path).config
            @sids={}
            @nats=nil
            @local_ip=nil
            @logger=Logger.new(config['logging']['file'])
        end
        attr_reader :config
        attr_reader :nats
        attr_reader :logger
        def setup_nats
            @nats = Nats.new(config['message_bus_uri'])
        end
        def run
            register_to_master
            register_task
            sub_task
        end
        def get_ip
            @local_ip||IPSocket.getaddress(Socket.gethostname)
        end
        def register_to_master
            EM::PeriodicTimer.new(1) do  
                p "client register"
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
            start_index=message.data["start_index"]
            end_index=message.data["end_index"]
            (start_index..end_index).each do |i|
                index=i%256
                p "sub task #{index}"
                sid=nats.subscribe("dea.#{index}.snapshot") do |message|
                    process_message(message)
                end
                @sids[index]=sid
            end
        end
        def register_task
            EM::PeriodicTimer.new(2) do
                index=@sids.keys
                p "task_register #{index}"
                nats.publish("task_register",{:index=>index})
            end
        end
        def process_message(message)
            p "getting message from dea #{message}"
            p message
        end
    end
end
