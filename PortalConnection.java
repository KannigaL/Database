
import java.sql.*; // JDBC stuff.
import java.util.Properties;

public class PortalConnection {

    // For connecting to the portal database on your local machine
    static final String DATABASE = "jdbc:postgresql://localhost/portal";
    static final String USERNAME = "postgres";
    static final String PASSWORD = "jonaslauri";

    // For connecting to the chalmers database server (from inside chalmers)
    // static final String DATABASE = "jdbc:postgresql://brage.ita.chalmers.se/";
    // static final String USERNAME = "tda357_nnn";
    // static final String PASSWORD = "yourPasswordGoesHere";

    // This is the JDBC connection object you will be using in your methods.
    private Connection conn;

    public PortalConnection() throws SQLException, ClassNotFoundException {
        this(DATABASE, USERNAME, PASSWORD);
    }

    // Initializes the connection, no need to change anything here
    public PortalConnection(String db, String user, String pwd) throws SQLException, ClassNotFoundException {
        Class.forName("org.postgresql.Driver");
        Properties props = new Properties();
        props.setProperty("user", user);
        props.setProperty("password", pwd);
        conn = DriverManager.getConnection(db, props);
        if(conn != null) {
            System.out.println("db is connected!");
        }
    }

    // Register a student on a course, returns a tiny JSON document (as a String)
    public String register(String student, String courseCode) {
        try(PreparedStatement ps1 = conn.prepareStatement("INSERT INTO Registrations VALUES (?,?)");) {
            ps1.setString(1, student);
            ps1.setString(2, courseCode) ;
            int insertions = ps1.executeUpdate();
            if (insertions > 0) {
                System.out.println("Inserted " + insertions + " records.");
                return "{\"success:\":true}" ;
            }
            else {
                return "{\"success\":false, \"error\":\"Registration did not work :(\"}";
            }
      } catch (SQLException e) {
         return "{\"success\":false, \"error\":\"" + getError(e) + "\"}";
      }
    }

    // Unregister a student from a course, returns a tiny JSON document (as a String)
    public String unregister(String student, String courseCode) {
        try(PreparedStatement ps2 = conn.prepareStatement("DELETE FROM Registrations WHERE student=? AND course =?");) {
            ps2.setString(1, student);
            ps2.setString(2, courseCode);
            int removals = ps2.executeUpdate();
            if (removals > 0) {
                System.out.println("Deleted " + removals + " records.");
                return "{\"success:\":true}";
            } else {
                return "{\"success\":false, \"error\":\"Unregistration did not work :(\"}";
            }
        } catch (SQLException e) {
            return getError(e);
        }
    }

    public String unregisterBad(String student, String courseCode) {
        String queryRegistered = "DELETE FROM Registered WHERE student='" + student + "' AND course='" + courseCode + "'";
        String queryWaiting = "DELETE FROM WaitingList WHERE student='" + student + "' AND course='" + courseCode + "'";
        try (Statement s = conn.createStatement();) {
            int r1 = s.executeUpdate(queryRegistered);
            int r2 = s.executeUpdate(queryWaiting);
            return "Deleted " + (r1 + r2) + " registrations.";
        } catch (SQLException e) {
            return getError(e);
        }
    }

    // Return a JSON document containing lots of information about a student.
    // It should validate against the schema found in information_schema.json.
    public String getInfo(String student) throws SQLException {
        try (PreparedStatement st = conn.prepareStatement(
                "SELECT jsonb_build_object('student',b.idnr,'name',b.name,'login',b.login,'program',b.program,'branch',COALESCE(b.branch,NULL)," +
                        " 'finished',jsonb_agg(DISTINCT jsonb_build_object('code',fc.course,'course',c.name,'credits',fc.credits,'grade',fc.grade))," +
                                " 'registered',(jsonb_agg(DISTINCT jsonb_build_object('code',r.course,'course',cn.name,'status',r.status,'position',q.place)))," +
                                "'seminarCourses',p.seminarcourses,'mathCredits',p.mathcredits,'researchCredits',p.researchcredits,'totalCredits',p.totalcredits,'canGraduate',p.qualified) AS jsondata" +
                                " FROM BasicInformation b" +
                                " LEFT JOIN FinishedCourses fc ON fc.student = b.idnr " +
                                " LEFT JOIN Registrations r ON r.student = b.idnr" +
                                " RIGHT JOIN PathToGraduation p ON p.student = b.idnr " +
                                " LEFT JOIN Courses c ON c.code = fc.course" +
                                " LEFT JOIN Courses cn ON cn.code = r.course" +
                                " LEFT JOIN CourseQueuePositions q ON q.student=r.student AND q.course = r.course" +
                                " WHERE idnr=? " +
                                " GROUP BY b.idnr,b.name,b.login,b.program,b.branch,p.seminarcourses,p.mathcredits,p.researchcredits,p.totalcredits,p.qualified"

            );) {
            st.setString(1, student);
            ResultSet rs = st.executeQuery();
            if (rs.next()) {
                return rs.getString("jsondata");
            } else {
                return "{\"student\":\"does not exist :(\"}";
            }
        } catch (SQLException e) {
            return getError(e);
        }
    }

    // This is a hack to turn an SQLException into a JSON string error message. No need to change.
    public static String getError(SQLException e){
       String message = e.getMessage();
       int ix = message.indexOf('\n');
       if (ix > 0) message = message.substring(0, ix);
       message = message.replace("\"","\\\"");
       return message;
    }
}