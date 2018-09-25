`ifndef TVIP_AXI_MASTER_ACCESS_SEQUENCE_SVH
`define TVIP_AXI_MASTER_ACCESS_SEQUENCE_SVH
class tvip_axi_master_access_sequence extends tvip_axi_master_sequence_base;
  rand  tvip_axi_access_type  access_type;
  rand  tvip_axi_id           id;
  rand  tvip_axi_address      address;
  rand  int                   burst_length;
  rand  int                   burst_size;
  rand  tvip_axi_burst_type   burst_type;
  rand  tvip_axi_data         data[];
  rand  tvip_axi_strobe       strobe[];
        tvip_axi_response     response[];
  rand  int                   write_data_delay[];
  rand  int                   response_ready_delay[];
        uvm_event             address_done_event;
        uvm_event             write_data_done_event;
        uvm_event             response_done_event;

  constraint c_valid_id {
    (id >> this.configuration.id_width) == 0;
  }

  constraint c_valid_address {
    (address >> this.configuration.address_width) == 0;
  }

  constraint c_valid_burst_length {
    burst_length inside {[1:this.configuration.max_burst_length]};
  }

  constraint c_valid_burst_size {
    burst_size inside {1, 2, 4, 8, 16, 32, 64, 128};
    (8 * burst_size) <= this.configuration.data_width;
  }

  constraint c_default_burst_type {
    burst_type == TVIP_AXI_INCREMENTING_BURST;
  }

  constraint c_valid_data {
    solve access_type  before data;
    solve burst_length before data;
    (access_type == TVIP_AXI_WRITE_ACCESS) -> data.size() == burst_length;
    (access_type == TVIP_AXI_READ_ACCESS ) -> data.size() == 0;
    foreach (data[i]) {
      (data[i] >> this.configuration.data_width) == 0;
    }
  }

  constraint c_valid_strobe {
    solve access_type  before strobe;
    solve burst_length before strobe;
    (access_type == TVIP_AXI_WRITE_ACCESS) -> strobe.size() == burst_length;
    (access_type == TVIP_AXI_READ_ACCESS ) -> strobe.size() == 0;
    foreach (strobe[i]) {
      (strobe[i] >> this.configuration.strobe_width) == 0;
    }
  }

  constraint c_write_data_delay_order_and_valid_size {
    solve access_type  before write_data_delay;
    solve burst_length before write_data_delay;
    (access_type == TVIP_AXI_WRITE_ACCESS) -> write_data_delay.size() == burst_length;
    (access_type == TVIP_AXI_READ_ACCESS ) -> write_data_delay.size() == 0;
  }

  `tvip_axi_declare_delay_consraint_array(
    write_data_delay,
    this.configuration.min_write_data_delay,
    this.configuration.mid_write_data_delay[0],
    this.configuration.mid_write_data_delay[1],
    this.configuration.max_write_data_delay,
    this.configuration.write_data_delay_weight[TVIP_AXI_ZERO_DELAY],
    this.configuration.write_data_delay_weight[TVIP_AXI_SHORT_DELAY],
    this.configuration.write_data_delay_weight[TVIP_AXI_LONG_DELAY]
  )

  constraint c_response_ready_delay_order_and_valid_size {
    solve access_type  before response_ready_delay;
    solve burst_length before response_ready_delay;
    (access_type == TVIP_AXI_WRITE_ACCESS) -> response_ready_delay.size() == 1;
    (access_type == TVIP_AXI_READ_ACCESS ) -> response_ready_delay.size() == burst_length;
  }

  `tvip_axi_declare_delay_consraint_array(
    response_ready_delay,
    get_min_response_ready_delay(access_type),
    get_mid_response_ready_delay(access_type, 0),
    get_mid_response_ready_delay(access_type, 1),
    get_max_response_ready_delay(access_type),
    get_response_delay_weight(access_type, TVIP_AXI_ZERO_DELAY ),
    get_response_delay_weight(access_type, TVIP_AXI_SHORT_DELAY),
    get_response_delay_weight(access_type, TVIP_AXI_LONG_DELAY )
  )

  function new(string name = "tvip_axi_master_access_sequence");
    super.new(name);
    address_done_event    = events.get("address_done");
    write_data_done_event = events.get("write_data_done");
    response_done_event   = events.get("response_done");
  endfunction

  task body();
    tvip_axi_master_item  item;
    create_request(item);
    fork
      `uvm_send(item)
      wait_for_progress(item);
    join
    copy_response(item);
  endtask

  local function void create_request(ref tvip_axi_master_item item);
    item                      = create_axi_item(access_type);
    item.id                   = id;
    item.address              = address;
    item.burst_length         = burst_length;
    item.burst_size           = burst_size;
    item.burst_type           = burst_type;
    item.response_ready_delay = new[response_ready_delay.size()](response_ready_delay);
    if (access_type == TVIP_AXI_WRITE_ACCESS) begin
      item.data             = new[data.size()](data);
      item.strobe           = new[strobe.size()](strobe);
      item.write_data_delay = new[write_data_delay.size()](write_data_delay);
    end
  endfunction

  local task wait_for_progress(tvip_axi_master_item item);
    fork
      begin
        item.address_end_event.wait_on();
        address_done_event.trigger();
      end
      if (access_type == TVIP_AXI_WRITE_ACCESS) begin
        item.write_data_end_event.wait_on();
        write_data_done_event.trigger();
      end
      begin
        item.response_end_event.wait_on();
        response_done_event.trigger();
      end
    join
  endtask

  local function void copy_response(tvip_axi_master_item item);
    response  = new[item.response.size()](item.response);
  endfunction

  local function int get_min_response_ready_delay(tvip_axi_access_type access_type);
    if (access_type == TVIP_AXI_WRITE_ACCESS) begin
      return configuration.min_bready_delay;
    end
    else begin
      return configuration.min_rready_delay;
    end
  endfunction

  local function int get_mid_response_ready_delay(tvip_axi_access_type access_type, int index);
    if (access_type == TVIP_AXI_WRITE_ACCESS) begin
      return configuration.mid_bready_delay[index];
    end
    else begin
      return configuration.mid_rready_delay[index];
    end
  endfunction

  local function int get_max_response_ready_delay(tvip_axi_access_type access_type);
    if (access_type == TVIP_AXI_WRITE_ACCESS) begin
      return configuration.max_bready_delay;
    end
    else begin
      return configuration.max_rready_delay;
    end
  endfunction

  local function int get_response_delay_weight(tvip_axi_access_type access_type, tvip_axi_delay_type delay_type);
    if (access_type == TVIP_AXI_WRITE_ACCESS) begin
      return configuration.bready_delay_weight[delay_type];
    end
    else begin
      return configuration.rready_delay_weight[delay_type];
    end
  endfunction

  `uvm_object_utils_begin(tvip_axi_master_access_sequence)
    `uvm_field_enum(tvip_axi_access_type, access_type, UVM_DEFAULT)
    `uvm_field_int(id, UVM_DEFAULT | UVM_HEX)
    `uvm_field_int(address, UVM_DEFAULT | UVM_HEX)
    `uvm_field_int(burst_length, UVM_DEFAULT | UVM_DEC)
    `uvm_field_int(burst_size, UVM_DEFAULT | UVM_DEC)
    `uvm_field_enum(tvip_axi_burst_type, burst_type, UVM_DEFAULT)
    `uvm_field_array_int(data, UVM_DEFAULT | UVM_HEX)
    `uvm_field_array_int(strobe, UVM_DEFAULT | UVM_HEX)
    `uvm_field_array_enum(tvip_axi_response, response, UVM_DEFAULT)
    `uvm_field_array_int(write_data_delay, UVM_DEFAULT | UVM_DEC | UVM_NOCOMPARE)
    `uvm_field_array_int(response_ready_delay, UVM_DEFAULT | UVM_DEC | UVM_NOCOMPARE)
  `uvm_object_utils_end
endclass
`endif