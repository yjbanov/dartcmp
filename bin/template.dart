const html = '''
<html>
<style>
  table.matching td {
    background-color: #ddffdd;
  }

  table.missing td {
    background-color: #ffdddd;
  }

  table.extra td {
    background-color: #ffffcc;
  }

  row {
    display: flex;
    flex-direction: row;
  }

  column {
    display: flex;
    flex-direction: column;
  }

  t-progress {
    display: flex;
    flex-direction: row;
    width: 100%;
  }

  done, doneish, todo {
    height: 20px;
    text-align: center;
    padding: 5px;
  }

  done {
    background-color: #ddffdd;
  }

  doneish {
    background-color: #ffffcc;
  }

  todo {
    background-color: #ffdddd;
  }
</style>
<body>
  <h1>Summary</h1>

  <h3>{{date}}</h3>

  <h2>Files</h2>

  <t-progress>
    <done style="width: {{files.done}}%">{{files.done}}%</done>
    <todo style="width: {{files.todo}}%">{{files.todo}}%</todo>
    <doneish style="width: {{files.doneish}}%">{{files.doneish}}%</doneish>
  </t-progress>

  <h2>Classes</h2>

  <t-progress>
    <done style="width: {{classes.done}}%">{{classes.done}}%</done>
    <todo style="width: {{classes.todo}}%">{{classes.todo}}%</todo>
    <doneish style="width: {{classes.doneish}}%">{{classes.doneish}}%</doneish>
  </t-progress>

  <h1>File delta</h1>

  <row>
    <column>
      <h2>Matching files ({{matchingFiles.length}})</h2>

      <table class="matching">
        {{#matchingFiles}}
        <tr>
          <td>{{.}}</td>
        </tr>
        {{/matchingFiles}}
      </table>
    </column>

    <column>
      <h2>Missing files ({{missingFiles.length}})</h2>

      <table class="missing">
        {{#missingFiles}}
        <tr>
          <td>{{.}}</td>
        </tr>
        {{/missingFiles}}
      </table>
    </column>

    <column>
      <h2>Extra files ({{extraFiles.length}})</h2>

      <table class="extra">
        {{#extraFiles}}
        <tr>
          <td>{{.}}</td>
        </tr>
        {{/extraFiles}}
      </table>
    </column>
  </row>

  <h1>Class delta</h1>

  <row>
    <column>
      <h2>Matching classes ({{matchingClasses.length}})</h2>

      <table class="matching">
        {{#matchingClasses}}
        <tr>
          <td>{{.}}</td>
        </tr>
        {{/matchingClasses}}
      </table>
    </column>

    <column>
      <h2>Missing classes ({{missingClasses.length}})</h2>

      <table class="missing">
        {{#missingClasses}}
        <tr>
          <td>{{.}}</td>
        </tr>
        {{/missingClasses}}
      </table>
    </column>

    <column>
      <h2>Misplaced classes ({{misplacedClasses.length}})</h2>

      <table class="extra">
        {{#misplacedClasses}}
        <tr>
          <td>{{.}}</td>
        </tr>
        {{/misplacedClasses}}
      </table>
    </column>

    <column>
      <h2>Extra classes ({{extraClasses.length}})</h2>

      <table class="extra">
        {{#extraClasses}}
        <tr>
          <td>{{.}}</td>
        </tr>
        {{/extraClasses}}
      </table>
    </column>
  </row>
</body>
</html>
''';
