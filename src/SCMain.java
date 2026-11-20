import java.io.*;

public class SCMain {
    public static void main(String[] args) throws Exception {
        Reader in = new InputStreamReader(System.in);
        SCParser parser = new SCParser(in, "<stdin>", 4096);
        Object result = parser.value(parser.pstart(0));
        if (result == null) {
            System.err.println("parse failed");
        } else {
            System.out.println(result);
        }
    }
}
