-- BasicInformation(idnr, name, login, program, branch)
CREATE VIEW BasicInformation AS
  SELECT s.idnr, s.name, s.login, s.program, sb.branch
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
