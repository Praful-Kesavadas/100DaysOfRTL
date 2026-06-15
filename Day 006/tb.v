module tb_bcd_7seg();
    reg [3:0] bcd;
    wire [6:0] segments;

    bcd_7seg uut(.bcd(bcd), .segments(segments));

    task display_visual(input [6:0] seg, input [3:0] bcd);
        begin
            // Active-low logic: 0 = ON, 1 = OFF
            $display("\nSimulated 7-Segment Display Output for %h", bcd);
            
            // Segment a (seg[6])
            $display("%s", seg[6] ? "      " : " ---- ");
            
            // Segments f (seg[1]) and b (seg[5])
            $display("%s     %s", seg[1] ? " " : "|", seg[5] ? " " : "|");
            $display("%s     %s", seg[1] ? " " : "|", seg[5] ? " " : "|");
            
            // Segment g (seg[0])
            $display("%s", seg[0] ? "      " : " ---- ");
            
            // Segments e (seg[2]) and c (seg[4])
            $display("%s     %s", seg[2] ? " " : "|", seg[4] ? " " : "|");
            $display("%s     %s", seg[2] ? " " : "|", seg[4] ? " " : "|");
            
            // Segment d (seg[3])
            $display("%s", seg[3] ? "      " : " ---- ");
            $display("------------------------------------");
        end
    endtask

    initial begin
        bcd = 4'b0010; #1 display_visual(segments, bcd);
        #10 bcd = 4'b0110; #1 display_visual(segments, bcd);
        #10 $finish;
    end

endmodule