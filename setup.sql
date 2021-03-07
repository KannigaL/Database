-- idnr=national identification number (10 digits)
-- Students(_idnr_, name, login, program)
CREATE TABLE Students (
 idnr CHAR(10) PRIMARY KEY, -- Primary key can not be null.
 name TEXT NOT NULL,
 login TEXT NOT NULL UNIQUE,
 program TEXT NOT NULL );

-- UNIQUE constraint making sure a student can not be in two different programs depending on where one looks.
ALTER TABLE Students ADD CONSTRAINT uc_sp UNIQUE (idnr, program);

-- Branches(_name_, _program_)
CREATE TABLE Branches (
 name TEXT,
 program TEXT,
 PRIMARY KEY (name, program) ); -- Primary key can not be null.

-- Courses(_code_, name, credits, department)
CREATE TABLE Courses (
 code CHAR(6) PRIMARY KEY, -- Primary key can not be null.
 name TEXT NOT NULL,
 credits FLOAT NOT NULL CHECK (credits >= 0), -- The number of credits must be non-negative.
 department TEXT NOT NULL );

-- Program(_name_, abbr)
CREATE TABLE Programs (
 name TEXT PRIMARY KEY,
 abbr TEXT NOT NULL );

-- Department(_name_, abbr)
CREATE TABLE Departments (
 name TEXT PRIMARY KEY,
 abbr TEXT NOT NULL UNIQUE );

-- LimitedCourses(_code_, capacity)
-- code → Courses.code
CREATE TABLE LimitedCourses (
 code CHAR(6) PRIMARY KEY REFERENCES Courses, -- When referencing to a primary key one can omit the attribute.
 capacity INTEGER NOT NULL CHECK (capacity >= 0) ); -- The capacity must be non-negative.

-- StudentBranches(_student_, branch, program)
--  student → Students.idnr
--  (branch, program) → Branches.(name, program)
CREATE TABLE StudentBranches (
 student TEXT PRIMARY KEY NOT NULL REFERENCES Students, -- When referencing to a primary key one can omit the attribute.
 branch TEXT NOT NULL,
 program TEXT NOT NULL,
 FOREIGN KEY (student, program) REFERENCES Students(idnr, program) );

-- Classifications(_name_)
CREATE TABLE Classifications (
 name TEXT PRIMARY KEY );

-- Classified(_course_, _classification_)
--  course → courses.code
--  classification → Classifications.name
CREATE TABLE Classified (
 course CHAR(6) REFERENCES Courses,
 classification TEXT REFERENCES Classifications,
 PRIMARY KEY (course, classification) );

-- MandatoryProgram(_course_, _program_)
--  course → Courses.code
CREATE TABLE MandatoryProgram (
 course CHAR(6) REFERENCES Courses,
 program TEXT,
 PRIMARY KEY (course, program) );

-- MandatoryBranch(_course_, _branch_, _program_)
--  course → Courses.code
--  (branch, program) → Branches.(name, program)
CREATE TABLE MandatoryBranch (
 course CHAR(6) REFERENCES Courses,
 branch TEXT NOT NULL,
 program TEXT NOT NULL,
 FOREIGN KEY (branch, program) REFERENCES Branches,
 PRIMARY KEY (course, branch, program) );

-- RecommendedBranch(_course_, _branch_, _program_)
--  course → Courses.code
--  (branch, program) → Branches.(name, program)
CREATE TABLE RecommendedBranch (
 course CHAR(6) REFERENCES Courses,
 branch TEXT NOT NULL,
 program TEXT NOT NULL,
 FOREIGN KEY (branch, program) REFERENCES Branches,
 PRIMARY KEY (course, branch, program) );

-- Registered(_student_, _course_)
--  student → Students.idnr
--  course → Courses.code
CREATE TABLE Registered (
 student CHAR(10) REFERENCES Students,
 course CHAR(6) REFERENCES Courses,
 PRIMARY KEY (student, course) );

-- Prerequisites(_course_, _prereq_)
--  course → Courses.code
--  prereq → Prerequisites.code
CREATE TABLE Prerequisites (
 course CHAR(6) REFERENCES Courses,
 prereq CHAR(6) REFERENCES Courses,
 PRIMARY KEY (course, prereq) );

-- Taken(_student_, _course_, grade)
--  student → Students.idnr
--  course → Courses.code
CREATE TABLE Taken (
 student CHAR(10) REFERENCES Students,
 course CHAR(6) REFERENCES Courses,
 grade CHAR(1) NOT NULL,
 CHECK (grade IN('U', '3', '4', '5')),
 PRIMARY KEY (student, course) );

-- WaitingList(_student_, _course_, position)
--  student → Students.idnr
--  course → Limitedcourses.code
-- Position is either a SERIAL, a TIMESTAMP or the actual position!
-- Used TIMESTAMP and therefore removed the position attribute in inserts.sql.
CREATE TABLE WaitingList (
 student CHAR(10) REFERENCES Students,
 course CHAR(6) REFERENCES LimitedCourses,
 position TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL UNIQUE,
 PRIMARY KEY (student, course) );

-- ProgramDepartment(_program_, department)
--  program → Programs.name
--  department → Departments.name
CREATE TABLE ProgramDepartment (
 program TEXT REFERENCES Programs, -- When referencing to a primary key one can omit the attribute.
 department TEXT REFERENCES Departments,
 PRIMARY KEY (program, department) );

-- BasicInformation(idnr, name, login, program, branch)
CREATE VIEW BasicInformation AS
  SELECT s.idnr, s.name, s.login, s.program, sb.branch
  FROM Students s
  LEFT JOIN StudentBranches sb
  ON s.idnr = sb.student;

-- Used to test last part of assignment 2.
CREATE VIEW BasicInformation2 AS
  SELECT s.idnr, s.name, s.login, sb.program, sb.branch
  FROM Students s
  LEFT JOIN StudentBranches sb
  ON s.idnr = sb.student;

-- FinishedCourses(student, course, grade, credits)
CREATE VIEW FinishedCourses AS
 SELECT t.student, t.course, t.grade, c.credits
 FROM Taken t
 LEFT JOIN Courses c
 ON t.course = c.code;

-- PassedCourses(student, course, credits)
CREATE VIEW PassedCourses AS
 SELECT t.student, t.course, c.credits
 FROM Taken t
 LEFT JOIN Courses c
 ON t.course = c.code
 WHERE (t.grade <> 'U'); -- Remove the failing students.

-- Registrations(student, course, status) -- First add the waiting list then union with the registered students.
CREATE VIEW Registrations AS
 SELECT w.student, w.course, 'waiting' AS status
 FROM WaitingList w
 UNION
 SELECT r.student, r.course, 'registered' AS status
 FROM Registered r
 LEFT JOIN WaitingList w
 ON w.position IS NULL;

-- UnreadMandatory(student, course)
CREATE VIEW UnreadMandatory AS
 SELECT s.idnr AS student, mp.course -- First add the mandatory courses for each program.
 FROM Students s
 RIGHT JOIN MandatoryProgram mp
 ON s.program = mp.program
 UNION
 SELECT sb.student, mb.course -- Then add the mandatory courses for each branch.
 FROM StudentBranches sb
 RIGHT JOIN MandatoryBranch mb
 ON sb.branch = mb.branch AND sb.program = mb.program -- Each branch belongs to a certain program.
 EXCEPT
 SELECT t.student, t.course -- Lastly remove any courses already passed.
 FROM Taken t
 WHERE (t.grade <> 'U');

-- Hint3(student, classification, credits)
CREATE VIEW Hint3 AS
 SELECT pc.student, c.classification, pc.credits
 FROM PassedCourses pc  -- PassedCourses(student, course, credits)
 LEFT JOIN Classified c  -- Classified(_course_, _classification_)
 ON pc.course = c.course;

-- PassedRecommended(student, course, credits, program, branch)
CREATE VIEW PassedRecommended AS
 SELECT pc.student, pc.course, pc.credits, rb.program, rb.branch
 FROM PassedCourses pc
 LEFT JOIN RecommendedBranch rb
 ON pc.course = rb.course;

-- TotalCredits(student, totalCredits)
CREATE VIEW TotalCredits AS
 SELECT s.idnr AS student, SUM(COALESCE(credits, 0)) AS totalCredits
 FROM Students s
 LEFT JOIN PassedCourses pc
 ON s.idnr IN(pc.student)
 GROUP BY s.idnr;

-- MandatoryLeft(student, mandatoryLeft)
CREATE VIEW MandatoryLeft AS
 SELECT s.idnr AS student, COUNT(um.course) AS mandatoryLeft
 FROM Students s
 LEFT JOIN UnreadMandatory um
 ON um.student = s.idnr
 GROUP BY s.idnr;

-- MathCredits(student, mathCredits)
CREATE VIEW MathCredits AS
 SELECT s.idnr AS student,
 CASE
  WHEN h.classification = 'math' THEN SUM(COALESCE(credits,0))
  ELSE 0
 END AS mathCredits
 FROM Students s
 LEFT JOIN Hint3 h
 ON s.idnr = h.student AND h.classification = 'math'
 GROUP BY h.classification, s.idnr;

-- ResearchCredits(student, researchCredits)
CREATE VIEW ResearchCredits AS
 SELECT s.idnr AS student, 0 AS totalCredits, 0 AS mandatoryLeft, 0 AS mathCredits,
 CASE
  WHEN h.classification = 'research' THEN SUM(COALESCE(credits,0))
  ELSE 0
 END AS researchCredits,
  0 AS seminarCourses, FALSE AS qualified
 FROM Students s
 LEFT JOIN Hint3 h
 ON s.idnr = h.student AND h.classification = 'research'
 GROUP BY h.classification, s.idnr;

-- SeminarCourses(student, seminarCourses)
CREATE VIEW SeminarCourses AS
SELECT s.idnr AS student,
 CASE
  WHEN h.classification = 'seminar' THEN COUNT(COALESCE(credits,0))
  ELSE 0
 END AS seminarCourses
 FROM Students s
 LEFT JOIN Hint3 h
 ON s.idnr = h.student AND h.classification = 'seminar'
 GROUP BY h.classification, s.idnr;

CREATE VIEW Qualified AS
 SELECT b.idnr AS student,
 CASE
  WHEN COUNT(um.course) != 0 THEN FALSE -- Passed all mandatory courses.
  WHEN SUM(COALESCE(pr.credits,0)) < 10 THEN FALSE -- 10 credits recommended courses for the branch.
  WHEN SUM(COALESCE(mc.mathCredits, 0)) < 20 THEN FALSE -- 20 credits math.
  WHEN SUM(COALESCE(rc.researchCredits, 0)) < 10 THEN FALSE -- 10 credits research.
  WHEN SUM(COALESCE(sc.seminarCourses, 0)) = 0 THEN FALSE -- 1 course seminar.
  ELSE TRUE
 END AS qualified
 FROM BasicInformation b
 LEFT JOIN UnreadMandatory um ON b.idnr = um.student
 LEFT JOIN PassedRecommended pr ON b.idnr = pr.student AND pr.program = b.program AND pr.branch = b.branch
 LEFT JOIN MathCredits mc ON b.idnr = mc.student
 LEFT JOIN ResearchCredits rc ON b.idnr = rc.student
 LEFT JOIN SeminarCourses sc ON b.idnr = sc.student
 GROUP BY b.idnr;

 -- PathToGraduation(student, totalCredits, mandatoryLeft, mathCredits, researchCredits, seminarCourses, qualified)
CREATE VIEW PathToGraduation AS
 SELECT s.idnr AS student, tc.totalCredits, ml.mandatoryLeft, mc.mathCredits, rc.researchCredits, sc.seminarCourses, q.qualified
 FROM Students s
 LEFT JOIN TotalCredits tc ON s.idnr = tc.student
 LEFT JOIN MandatoryLeft ml ON s.idnr = ml.student
 LEFT JOIN MathCredits mc ON s.idnr = mc.student
 LEFT JOIN ResearchCredits rc ON s.idnr = rc.student
 LEFT JOIN SeminarCourses sc ON s.idnr = sc.student
 LEFT JOIN Qualified q ON s.idnr = q.student
 GROUP BY s.idnr, tc.totalCredits, ml.MandatoryLeft, mc.MathCredits, rc.researchCredits, sc.seminarCourses, q.qualified;

INSERT INTO Branches VALUES ('B1', 'Prog1');
INSERT INTO Branches VALUES ('B2', 'Prog1');
INSERT INTO Branches VALUES ('B1', 'Prog2');

INSERT INTO Students VALUES ('1111111111', 'N1', 'ls1', 'Prog1');
INSERT INTO Students VALUES ('2222222222', 'N2', 'ls2', 'Prog1');
INSERT INTO Students VALUES ('3333333333', 'N3', 'ls3', 'Prog2');
INSERT INTO Students VALUES ('4444444444', 'N4', 'ls4', 'Prog1');
INSERT INTO Students VALUES ('5555555555', 'Nx', 'ls5', 'Prog2');
INSERT INTO Students VALUES ('6666666666', 'Nx', 'ls6', 'Prog2');

INSERT INTO Courses VALUES ('CCC111', 'C1', 22.5, 'Dep1');
INSERT INTO Courses VALUES ('CCC222', 'C2', 20,   'Dep1');
INSERT INTO Courses VALUES ('CCC333', 'C3', 30,   'Dep1');
INSERT INTO Courses VALUES ('CCC444', 'C4', 40,   'Dep1');
INSERT INTO Courses VALUES ('CCC555', 'C5', 50,   'Dep1');

INSERT INTO Programs VALUES ('Prog1', 'P1');
INSERT INTO Programs VALUES ('Prog2', 'P2');
INSERT INTO Programs VALUES ('Prog3', 'P3');

INSERT INTO Departments VALUES ('Dep1', 'D1');
INSERT INTO Departments VALUES ('Dep2', 'D2');

INSERT INTO LimitedCourses VALUES ('CCC222', 2);
INSERT INTO LimitedCourses VALUES ('CCC333', 2);

INSERT INTO Classifications VALUES ('math');
INSERT INTO Classifications VALUES ('research');
INSERT INTO Classifications VALUES ('seminar');

INSERT INTO Classified VALUES ('CCC333', 'math');
INSERT INTO Classified VALUES ('CCC444', 'research');
INSERT INTO Classified VALUES ('CCC444','seminar');

INSERT INTO StudentBranches VALUES ('2222222222', 'B1', 'Prog1');
INSERT INTO StudentBranches VALUES ('3333333333', 'B1', 'Prog2');
INSERT INTO StudentBranches VALUES ('4444444444', 'B1', 'Prog1');
-- INSERT INTO StudentBranches VALUES ('5555555555', 'B2', 'Prog1'); -- Should make the program crash.

INSERT INTO MandatoryProgram VALUES ('CCC111', 'Prog1');

INSERT INTO MandatoryBranch VALUES ('CCC333', 'B1', 'Prog1');
INSERT INTO MandatoryBranch VALUES ('CCC555', 'B1', 'Prog2');

INSERT INTO RecommendedBranch VALUES ('CCC222', 'B1', 'Prog1');
INSERT INTO RecommendedBranch VALUES ('CCC333', 'B2', 'Prog1');

INSERT INTO Registered VALUES ('1111111111', 'CCC111');
INSERT INTO Registered VALUES ('1111111111', 'CCC222');
INSERT INTO Registered VALUES ('2222222222', 'CCC222');
INSERT INTO Registered VALUES ('5555555555', 'CCC333');
INSERT INTO Registered VALUES ('1111111111', 'CCC333');

INSERT INTO Prerequisites VALUES ('CCC555', 'CCC111');

-- Using TIMESTAMP, therefore removed the position parameters.
INSERT INTO WaitingList VALUES ('3333333333', 'CCC222');
INSERT INTO WaitingList VALUES ('3333333333', 'CCC333');
INSERT INTO WaitingList VALUES ('4444444444', 'CCC333');
INSERT INTO WaitingList VALUES ('2222222222', 'CCC333');
INSERT INTO WaitingList VALUES ('5555555555', 'CCC222');
INSERT INTO WaitingList VALUES ('6666666666', 'CCC333');

INSERT INTO Taken VALUES('2222222222', 'CCC111', 'U');
INSERT INTO Taken VALUES('2222222222', 'CCC222', 'U');
INSERT INTO Taken VALUES('2222222222', 'CCC444', 'U');

INSERT INTO Taken VALUES('4444444444', 'CCC111', '5');
INSERT INTO Taken VALUES('4444444444', 'CCC222', '5');
INSERT INTO Taken VALUES('4444444444', 'CCC333', '5');
INSERT INTO Taken VALUES('4444444444', 'CCC444', '5');

INSERT INTO Taken VALUES('5555555555', 'CCC111', '5');
INSERT INTO Taken VALUES('5555555555', 'CCC333', '5');
INSERT INTO Taken VALUES('5555555555', 'CCC444', '5');

INSERT INTO ProgramDepartment VALUES ('Prog1', 'Dep1');
INSERT INTO ProgramDepartment VALUES ('Prog2', 'Dep2');

