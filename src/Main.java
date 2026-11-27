import java.io.*;

public class Main {
    public static void main(String[] args) throws Exception {
        Reader in = new InputStreamReader(System.in, "UTF-8");
        TascellC parser = new TascellC(in, "<stdin>");
        try {
            System.out.println(parser.value(parser.pstart(0)));
        } catch (xtc.parser.ParseException e) {
            System.err.println(e.getMessage());
            System.exit(1);
        }
    }
}
