#!/usr/bin/env ruby

# -------------------------------------------------------------------------- #
# Copyright 2002-2012, OpenNebula Project Leads (OpenNebula.org)             #
#                                                                            #
# Licensed under the Apache License, Version 2.0 (the "License"); you may    #
# not use this file except in compliance with the License. You may obtain    #
# a copy of the License at                                                   #
#                                                                            #
# http://www.apache.org/licenses/LICENSE-2.0                                 #
#                                                                            #
# Unless required by applicable law or agreed to in writing, software        #
# distributed under the License is distributed on an "AS IS" BASIS,          #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   #
# See the License for the specific language governing permissions and        #
# limitations under the License.                                             #
#--------------------------------------------------------------------------- #

ONE_LOCATION = ENV["ONE_LOCATION"]

if !ONE_LOCATION
    RUBY_LIB_LOCATION = "/usr/lib/one/ruby"
    ETC_LOCATION      = "/etc/one/"
else
    RUBY_LIB_LOCATION = ONE_LOCATION + "/lib/ruby"
    ETC_LOCATION      = ONE_LOCATION + "/etc/"
end

$: << RUBY_LIB_LOCATION

DUMMY_ACTIONS_DIR = "/tmp/opennebula_dummy_actions"

require "VirtualMachineDriver"
require "CommandManager"

# This is a dummy driver for the Virtual Machine management
#
# By default all the actions will succeed
#
# Action results can be specified in the DUMMY_ACTIONS_DIRS
#   * Example, Next deploy will fail
#       echo "failure" > $DUMMY_ACTIONS_DIR/deploy
#     If this file is not removed next deploy actions will fail
#       rm $DUMMY_ACTIONS_DIR/deploy
#         or
#       echo "success" > $DUMMY_ACTIONS_DIR/deploy
#
#   * Example, Defining multiple results per action
#       echo "success\nfailure" > $DUMMY_ACTIONS_DIR/deploy
#     The 1st deploy will succeed and the 2nd will fail. This
#       behavior will be repeated, i.e 3th success, 4th failure


class DummyDriver < VirtualMachineDriver
    def initialize
        super('',
            :concurrency => 15,
            :threaded => true
        )

        `mkdir #{DUMMY_ACTIONS_DIR}`

        @actions_counter = Hash.new(0)
    end

    def deploy(id, drv_message)
        msg = decode(drv_message)

        host = msg.elements["HOST"].text
        name = msg.elements["VM/NAME"].text

        result = retrieve_result("deploy")

        send_message(ACTION[:deploy],result,id,"#{host}:#{name}:dummy")
    end

    def shutdown(id, drv_message)
        result = retrieve_result("shutdown")

        send_message(ACTION[:shutdown],result,id)
    end

    def reboot(id, drv_message)
        result = retrieve_result("reboot")

        send_message(ACTION[:reboot],result,id)
    end

    def reset(id, drv_message)
        result = retrieve_result("reset")

        send_message(ACTION[:reset],result,id)
    end

    def cancel(id, drv_message)
        result = retrieve_result("cancel")

        send_message(ACTION[:cancel],result,id)
    end

    def save(id, drv_message)
        result = retrieve_result("save")

        send_message(ACTION[:save],result,id)
    end

    def restore(id, drv_message)
        result = retrieve_result("restore")

        send_message(ACTION[:restore],result,id)
    end

    def migrate(id, drv_message)
        result = retrieve_result("migrate")

        send_message(ACTION[:migrate],result,id)
    end

    def attach_disk(id, drv_message)
        result = retrieve_result("attach_disk")

        send_message(ACTION[:attach_disk],result,id)
    end

    def detach_disk(id, drv_message)
        result = retrieve_result("detach_disk")

        send_message(ACTION[:detach_disk],result,id)
    end

    def poll(id, drv_message)
        result = retrieve_result("poll")

        msg = decode(drv_message)

        max_memory = 256
        if msg.elements["VM/TEMPLATE/MEMORY"]
            max_memory = msg.elements["VM/TEMPLATE/MEMORY"].text.to_i * 1024
        end

        max_cpu = 100
        if msg.elements["VM/TEMPLATE/CPU"]
            max_cpu = msg.elements["VM/TEMPLATE/CPU"].text.to_i * 100
        end

        prev_nettx = 0
        if msg.elements["VM/NET_TX"]
            prev_nettx = msg.elements["VM/NET_TX"].text.to_i
        end

        prev_netrx = 0
        if msg.elements["VM/NET_RX"]
            prev_netrx = msg.elements["VM/NET_RX"].text.to_i
        end

        # monitor_info: string in the form "VAR=VAL VAR=VAL ... VAR=VAL"
        # known VAR are in POLL_ATTRIBUTES. VM states VM_STATES
        monitor_info = "#{POLL_ATTRIBUTE[:state]}=#{VM_STATE[:active]} " \
                       "#{POLL_ATTRIBUTE[:nettx]}=#{prev_nettx+(50*rand(3))} " \
                       "#{POLL_ATTRIBUTE[:netrx]}=#{prev_netrx+(100*rand(4))} " \
                       "#{POLL_ATTRIBUTE[:usedmemory]}=#{max_memory * (rand(80)+20)/100} " \
                       "#{POLL_ATTRIBUTE[:usedcpu]}=#{max_cpu * (rand(95)+5)/100}" 

        send_message(ACTION[:poll],result,id,monitor_info)
    end

    private

    def retrieve_result(action)
        begin
            actions = File.read(DUMMY_ACTIONS_DIR+"/#{action}")
        rescue
            return RESULT[:success]
        end

        actions_array = actions.split("\n")
        action_id     = @actions_counter[action]
        action_id     %= actions_array.size

        if actions_array && actions_array[action_id]
            result = actions_array[action_id]
            if result == "success" || result == 0 || result == "0"
                return RESULT[:success]
            else
                return RESULT[:failure]
            end

            @actions_counter[action] += 1
        else
            return RESULT[:success]
        end

    end
end

dd = DummyDriver.new
dd.start_driver