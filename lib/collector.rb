require "config"
require "nats"
require 'socket'
require "logger"
require "database"

module Collector
    class Collector
        def initialize(config_path)
            @config=Config.new(config_path).config
            @sids_dea_meta={}
            @sids_instance_resource={}
            @sids_instance_meta={}
            @sids_instance_existence_register={}
            setup_log
            setup_nats
        end
        attr_reader :config
        attr_reader :nats
        attr_reader :logger
        def setup_log
            #@logger=Logger.new(config['logging']['file'])
            @logger=Logger.new(STDOUT)
            @logger.datetime_format = "%Y-%m-%d %H:%M:%S"
            @logger.formatter = proc do |severity, datetime, progname, msg|
                "[#{datetime}] #{severity} : #{msg}\n"
            end
            @logger.level = Logger::DEBUG
        end
        def setup_nats
            @nats = Nats.new(self,config['message_bus_uri'])
        end
        def run
            begin
                register_to_master
                register_task
                sub_task
                remove_dead_instance
                remove_dead_dea
            rescue => e
                logger.error("Error in collector:#{e.message} #{e.backtrace}")
            end
        end
        def get_ip
            @local_ip||IPSocket.getaddress(Socket.gethostname)
        end
        def remove_dead_instance
            begin
                EM::PeriodicTimer.new(5) do
                    time_delete=Time.now.to_i-5
                    InstanceStatus.where("time < #{time_delete}").destroy_all
                end
            rescue => e
                logger.error("Error in remove dead instance:#{e.message} #{e.backtrace}")
            end
        end

        def remove_dead_dea
            begin
                EM::PeriodicTimer.new(60) do
                    time_delete=Time.now.to_i-60
                    DeaList.where("time < #{time_delete}").destroy_all
                end
            rescue => e
                logger.error("Error in remove dead instance:#{e.message} #{e.backtrace}")
            end
        end
        def register_to_master
            begin
                EM::PeriodicTimer.new(3) do  
                    logger.debug("register to collector master")
                    data={:ip=>get_ip}
                    nats.publish("collector_register",data)
                end
            rescue => e
                logger.error("Error in register to master:#{e.message} #{e.backtrace}")
            end
        end
        def sub_task
            begin
                nats.subscribe("collector_task_#{get_ip}") do |message|
                    logger.debug("get collector task")
                    clear_collect
                    collect(message)
                end
            rescue => e
                logger.error("Error in sub task:#{e.message} #{e.backtrace}")
            end
        end
        def clear_collect
            begin
                logger.debug("clear collector task")
                @sids_dea_meta.each { |_, sid| nats.unsubscribe(sid) }
                @sids_dea_meta={}
                @sids_instance_resource.each { |_, sid| nats.unsubscribe(sid) }
                @sids_instance_resource={}
                @sids_instance_meta.each { |_, sid| nats.unsubscribe(sid) }
                @sids_instance_meta={}
                @sids_instance_existence_register.each { |_, sid| nats.unsubscribe(sid) }
                @sids_instance_existence_register={}
            rescue => e
                logger.error("Error in clear collect:#{e.message} #{e.backtrace}")
            end
        end
        def collect(message) 
            start_index=message.data["start_index"]
            end_index=message.data["end_index"]
            collect_instance_meta(start_index,end_index)
            collect_instance_resource(start_index,end_index)
            collect_dea_meta(start_index,end_index)
            collect_instance_existence_register(start_index,end_index)
        end

        def collect_instance_meta(start_index,end_index)
            begin
                (start_index..end_index).each do |i|
                    index=i%256
                    logger.debug("sub instance meta #{index}")
                    sid=nats.subscribe("dea.#{index}.metadata") do |message|
                        process_instance_meta(message)
                    end
                    @sids_instance_meta[index]=sid
                end
            rescue => e
                logger.error("Error in collect instance meta:#{e.message} #{e.backtrace}")
            end
        end

        def collect_instance_resource(start_index,end_index)
            begin
                (start_index..end_index).each do |i|
                    index=i%256
                    logger.debug("sub instance_resource #{index}")
                    sid=nats.subscribe("dea.#{index}.usagedata") do |message|
                        process_instance_resource(message)
                    end
                    @sids_instance_resource[index]=sid
                end
            rescue => e
                logger.error("Error in collect instance meta:#{e.message} #{e.backtrace}")
            end
        end

        def collect_dea_meta(start_index,end_index)
            begin
                (start_index..end_index).each do |i|
                    index=i%256
                    logger.debug("sub dea meta #{index}")
                    sid=nats.subscribe("dea.#{index}.nodedata") do |message|
                        process_dea_meta(message)
                    end
                    @sids_dea_meta[index]=sid
                end
            rescue => e
                logger.error("Error in collect instance meta:#{e.message} #{e.backtrace}")
            end
        end

        def collect_instance_existence_register(start_index,end_index)
            begin
                (start_index..end_index).each do |i|
                    index=i%256
                    logger.debug("sub instance existence register #{index}")
                    sid=nats.subscribe("dea.#{index}.check") do |message|
                        process_instance_existence_register(message)
                    end
                    @sids_instance_existence_register[index]=sid
                end
            rescue => e
                logger.error("Error in collect instance existence register:#{e.message} #{e.backtrace}")
            end
        end

        def register_task
            begin
                EM::PeriodicTimer.new(5) do
                    index=@sids_dea_meta.keys
                    logger.debug("task register #{index}")
                    nats.publish("task_register",{:index=>index})
                end
            rescue => e
                logger.error("Error in register task:#{e.message} #{e.backtrace}")
            end
        end
        def process_instance_meta(message)
            begin
                instance_meta=message.data
                instance_info={}
                instance_info['state']=instance_meta['state']
                instance_info['time']=Time.now.to_i
                instance_info['host']="0.0.0.0"
                instance_info['space']=instance_meta['tags']['space_name']
                instance_info['organization']=instance_meta['tags']['org_name']
                instance_info['bns_node']=instance_meta['tags']['bns_node']
                instance_info['app_name']=instance_meta['application_name']
                instance_info['uris']=instance_meta['application_uris'].join(",")
                instance_info['instance_index']=instance_meta['instance_index']
                instance_info['cluster_num']="unknown"
                instance_info['warden_handle']=instance_meta['warden_handle']
                instance_info['warden_container_path']=instance_meta['warden_container_path']
                instance_info['state_starting_timestamp']=instance_meta['state_starting_timestamp']
                instance_info['port_info']=instance_meta['instance_meta']['prod_ports'].to_json.to_s
                instance_info['noah_monitor_port']=instance_meta['noah_monitor_host_port']
                instance_info['warden_host_ip']=instance_meta['warden_host_ip']
                instance_info['instance_id']=instance_meta['instance_id']
                instance_info['disk_quota']=instance_meta['limits']['disk']
                instance_info['mem_quota']=instance_meta['limits']['mem']
                instance_info['fds_quota']=instance_meta['limits']['fds']
                InstanceStatus.where(
                    :instance_id=>instance_info['instance_id']
                ).first_or_create.update_attributes(instance_info)
            rescue => e
                logger.error("Error in process instance meta:#{e.message} #{e.backtrace}")
            end
        end
        
        def process_instance_resource(message)
            begin
              instance_resource=message.data
              instance_info={}
              instance_info['instance_id']=instance_resource["instance_id"]
              instance_info['time']=Time.now.to_i
              instance_info['cpu_usage']=instance_resource["usage"]["cpu"]
              instance_info['mem_usage']=instance_resource["usage"]["mem"]
              instance_info['fds_usage']=instance_resource["usage"]["fds"]
              InstanceStatus.where(
                  :instance_id=>instance_info['instance_id']
              ).first_or_create.update_attributes(instance_info)
            rescue => e
                logger.error("Error in process instance resource:#{e.message} #{e.backtrace}")
            end
        end

        def process_dea_meta(message) 
            begin 
                dea=message.data
                dea_info={}
                dea_info["uuid"]=dea["uuid"]
                dea_info["ip"]=dea["ip"]
                dea_info["cluster_num"]="unknown"
                dea_info["time"]=Time.now.to_i
                DeaList.where(
                    :uuid=>dea_info["uuid"]
                ).first_or_create.update_attributes(dea_info)
            rescue => e
                logger.error("Error in process dea meta:#{e.message} #{e.backtrace}")
            end
        end

        def process_instance_existence_register(message)
            begin
                instance_id=message.data["instance_id"]
                if InstanceStatus.where(:instance_id=>instance_id).empty?
                    message.respond({"status"=>"bad"})
                else
                    message.respond({"status"=>"ok"})
                end
            rescue => e
                logger.error("Error in process instance existence register:#{e.message} #{e.backtrace}")
            end
        end
    end
end
