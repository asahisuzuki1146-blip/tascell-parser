import java.io.*;

public class Main {
    public static void main(String[] args) throws Exception {
        Reader in = new InputStreamReader(System.in);
        TascellC parser = new TascellC(in, "<stdin>", 4096);
        Object result = parser.value(parser.pstart(0));
        if (result == null) {
            System.err.println("parse failed");
        } else {
            System.out.println(result);
        }
    }
}
