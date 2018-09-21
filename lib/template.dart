// Copyright 2018 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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

  <h2>Tests</h2>

  <t-progress>
    <done style="width: {{testFiles.done}}%">{{testFiles.done}}%</done>
    <todo style="width: {{testFiles.todo}}%">{{testFiles.todo}}%</todo>
    <doneish style="width: {{testFiles.doneish}}%">{{testFiles.doneish}}%</doneish>
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

  <h1>Test delta</h1>

  <row>
    <column>
      <h2>Matching tests ({{matchingTestFiles.length}})</h2>

      <table class="matching">
        {{#matchingTestFiles}}
        <tr>
          <td>{{.}}</td>
        </tr>
        {{/matchingTestFiles}}
      </table>
    </column>

    <column>
      <h2>Missing tests ({{missingTestFiles.length}})</h2>

      <table class="missing">
        {{#missingTestFiles}}
        <tr>
          <td>{{.}}</td>
        </tr>
        {{/missingTestFiles}}
      </table>
    </column>

    <column>
      <h2>Extra tests ({{extraTestFiles.length}})</h2>

      <table class="extra">
        {{#extraTestFiles}}
        <tr>
          <td>{{.}}</td>
        </tr>
        {{/extraTestFiles}}
      </table>
    </column>
  </row>
</body>
</html>
''';
