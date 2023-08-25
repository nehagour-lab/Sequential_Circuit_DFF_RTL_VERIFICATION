class transaction;
    rand bit din;
    bit dout;
    bit rst;
  
    function void display(input string tag);
      $display("[%0s] \t DIN::: %0d, \t DOUT::: %0d \t RESET::::%0d ",tag,din,dout,rst);
    endfunction

    function transaction copy();
      copy = new();
      copy.din = this.din;		
      copy.dout = this.dout;		
    endfunction
  
endclass


class generator;
     transaction tg;
     mailbox #(transaction) mbx;
     mailbox #(transaction) g_mbx;
  
      event done;
      event next;
      int count;
  
    function new (mailbox #(transaction) mbx,  mailbox #(transaction) g_mbx);
        this.mbx = mbx;
        this.g_mbx = g_mbx;
        tg = new();
    endfunction 
  
    task run ();
      repeat(count)
        begin
          assert(tg.randomize()) else $display("RANDOMIZATION FAILED");
          mbx.put(tg.copy); 
          g_mbx.put(tg.copy);
          tg.display("GENERATOR");
          @(next); //////////////////////////CLOCK///////////////////////////////
        end
    ->done;       //////////////////////////CLOCK///////////////////////////////
    endtask
  
endclass
 

class driver;
    transaction td;
    virtual dff_if dif;
    mailbox #(transaction) mbx;

    function new(mailbox #(transaction) mbx);
      	this.mbx = mbx;
    endfunction
  
    task reset;
        dif.rst <= 1'b1;
        repeat(2) @(posedge dif.clk);////////////////////CLOCK///////////////////////////////
        dif.rst <=1'b0;
        @(posedge dif.clk); //////////////////////////CLOCK///////////////////////////////
        $display("*****************RESET DUT****************");   
    endtask
  
    task run ();
        td = new();
        forever begin
        mbx.get(td);
        dif.din <= td.din;		//TRANSACTION TO INTERFACE///////////////////////////////
        td.display("DRIVER");
          @(posedge dif.clk); /////////////////////////////////CLOCK/////////////////////
        end
    endtask

endclass
    

class monitor;
  
    transaction tm;
    virtual dff_if dif;
    mailbox #(transaction) mbx;

    function new (mailbox #(transaction) mbx);
    	  this.mbx = mbx;
    endfunction

    task run ();
        tm = new();
     forever begin
          @(posedge dif.clk);		//half clock cycle
          @(posedge dif.clk);		//half clock cycle
          tm.dout = dif.dout;		//INTERFACE to TRANSACTION/////////////////////////
          mbx.put(tm);
          tm.display("MONITOR");
      end

    endtask
  
endclass
    
class scoreboard;
    
      transaction tm;
      transaction tm_ref;
      mailbox #(transaction) mbx;
      mailbox #(transaction) s_mbx;
      event sconext;

      function new (mailbox #(transaction) mbx, mailbox #(transaction) s_mbx);
        this.mbx = mbx;
        this.s_mbx = s_mbx;
      endfunction
  
  task run ();
    tm = new();
    tm_ref = new();
    
    forever begin 
      
      mbx.get(tm);
      tm.display("SCOREBOARD");
      s_mbx.get(tm_ref);
      tm_ref.display("REFERENCE");
      
      if(tm.dout == tm_ref.din) 
        $display("DATA MATCHED!");
      else
        $display("DATA MISMATCHED!");
      
       ->sconext;  ///////////////clock/////////////////////////////////
    end
  endtask
  
endclass
    
class environment;
  	 generator gen;
  	 driver drv;
  	 monitor mon;
  	 scoreboard sco;
  
  mailbox #(transaction) gd_mbx;
  mailbox #(transaction) ms_mbx;
  mailbox #(transaction) sg_mbx;
  
  virtual dff_if dif;
  event next;
  
  function new(virtual dff_if dif);
    
    gd_mbx = new();
    sg_mbx = new();
    gen = new(gd_mbx,sg_mbx);
    drv = new(gd_mbx);
    ms_mbx = new();
    mon = new(ms_mbx);
    sco = new(ms_mbx,sg_mbx);
    
    this.dif = dif;
    mon.dif = this.dif;
    drv.dif = this.dif;
    ////////////////////////clock//////////////////////
    gen.next = next;
    sco.sconext = next;
    
  endfunction
  
  
  task pre_test();
    drv.reset();
  endtask
  
  task test();
   fork
    gen.run();
    drv.run();
    mon.run();
    sco.run(); 
   join_any
  endtask
  
  task post_test();
    wait(gen.done.triggered); ///////////////////////////clock//////////////
    $finish;
  endtask
  
  task run();
    pre_test();
    test();
    post_test();
  endtask
  
endclass
     
     module dff_tb;
       
       environment env;
       dff_if dif();
       dff dut(dif); // as we defined interface in design
       
       initial begin 
         dif.clk <= 0;
       end
       
       always #10 dif.clk <= ~dif.clk;
       
       initial begin 
         env = new(dif);
         env.gen.count = 10;
         env.run();
         
       end
       
       initial 
         begin
           $dumpfile("dump.vcd");
           $dumpvars;
         end
     endmodule
