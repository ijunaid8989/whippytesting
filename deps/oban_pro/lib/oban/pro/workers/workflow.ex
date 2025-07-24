defmodule Oban.Pro.Workers.Workflow do
  @moduledoc ~S"""
  Workflow workers compose together with arbitrary dependencies between jobs, allowing sequential,
  fan-out, and fan-in execution workflows. Workflows are fault tolerant, can be homogeneous or
  heterogeneous, and scale horizontally across all available nodes.

  Workflow jobs aren't executed until all upstream dependencies have completed. This includes
  waiting on retries, scheduled jobs, or snoozing.

  ## Installation

  Before running a `Workflow` in production, you should run a migration to add an optimized index
  for workflow queries. Without the optimization workflow queries may be very slow:

  ```elixir
  defmodule MyApp.Repo.Migrations.AddWorkflowIndex do
    use Ecto.Migration

    defdelegate change, to: Oban.Pro.Migrations.Workflow
  end
  ```

  Also, be sure that you're running the `DynamicLifeline` to rescue stuck workflows when upstream
  dependencies are deleted unexpectedly.

  ```elixir
  config :my_app, Oban,
    plugins: [Oban.Pro.Plugins.DynamicLifeline],
    ...
  ```

  ## Usage

  Workflows are ideal for linking jobs together into a directed acyclic graph, a DAG. Dependency
  resolution guarantees that jobs execute in the prescribed order, even if one of the jobs fails
  and needs to retry. Any job that defines a dependency will wait for each upstream dependency to
  complete before it starts.

  As a trivial example, we'll define an `EchoWorker` that only inspects that `args`, and then
  use it in a workflow to show how jobs execute in order. First, here's the worker:

  ```elixir
  defmodule MyApp.EchoWorker do
    use Oban.Pro.Workers.Workflow, queue: :default

    @impl true
    def process(%{args: args}) do
      IO.inspect(args)

      :ok
    end
  end
  ```

  Now, we'll use `new/1` to initialize a workflow, and `add/4` to add named jobs with dependencies
  to the workflow:

  ```elixir
  alias MyApp.EchoWorker
  alias Oban.Pro.Workers.Workflow

  Workflow.new()
  |> Workflow.add(:a, EchoWorker.new(%{id: 1}))
  |> Workflow.add(:b, EchoWorker.new(%{id: 2}), deps: [:a])
  |> Workflow.add(:c, EchoWorker.new(%{id: 3}), deps: [:b])
  |> Workflow.add(:d, EchoWorker.new(%{id: 4}), deps: [:b])
  |> Workflow.add(:e, EchoWorker.new(%{id: 5}), deps: [:c, :d])
  |> Oban.insert_all()
  ```

  When the workflow executes, it will print out each job's `args` in the prescribed order.
  However, because steps `c` and `d` each depend on `b`, they may execute in parallel.

  Visually, the workflow jobs composes like this:

  <svg role="graphics-document document" viewBox="-8 -8 262.8666687011719 144" style="max-width: 600px;" xmlns="http://www.w3.org/2000/svg" id="graph-div" height="400px" xmlns:xlink="http://www.w3.org/1999/xlink"><style>#graph-div{font-family:"trebuchet ms",verdana,arial,sans-serif;font-size:16px;fill:#000000;}#graph-div .error-icon{fill:#552222;}#graph-div .error-text{fill:#552222;stroke:#552222;}#graph-div .edge-thickness-normal{stroke-width:2px;}#graph-div .edge-thickness-thick{stroke-width:3.5px;}#graph-div .edge-pattern-solid{stroke-dasharray:0;}#graph-div .edge-pattern-dashed{stroke-dasharray:3;}#graph-div .edge-pattern-dotted{stroke-dasharray:2;}#graph-div .marker{fill:#666;stroke:#666;}#graph-div .marker.cross{stroke:#666;}#graph-div svg{font-family:"trebuchet ms",verdana,arial,sans-serif;font-size:16px;}#graph-div .label{font-family:"trebuchet ms",verdana,arial,sans-serif;color:#000000;}#graph-div .cluster-label text{fill:#333;}#graph-div .cluster-label span,#graph-div p{color:#333;}#graph-div .label text,#graph-div span,#graph-div p{fill:#000000;color:#000000;}#graph-div .node rect,#graph-div .node circle,#graph-div .node ellipse,#graph-div .node polygon,#graph-div .node path{fill:#eee;stroke:#999;stroke-width:1px;}#graph-div .flowchart-label text{text-anchor:middle;}#graph-div .node .katex path{fill:#000;stroke:#000;stroke-width:1px;}#graph-div .node .label{text-align:center;}#graph-div .node.clickable{cursor:pointer;}#graph-div .arrowheadPath{fill:#333333;}#graph-div .edgePath .path{stroke:#666;stroke-width:2.0px;}#graph-div .flowchart-link{stroke:#666;fill:none;}#graph-div .edgeLabel{background-color:white;text-align:center;}#graph-div .edgeLabel rect{opacity:0.5;background-color:white;fill:white;}#graph-div .labelBkg{background-color:rgba(255, 255, 255, 0.5);}#graph-div .cluster rect{fill:hsl(0, 0%, 98.9215686275%);stroke:#707070;stroke-width:1px;}#graph-div .cluster text{fill:#333;}#graph-div .cluster span,#graph-div p{color:#333;}#graph-div div.mermaidTooltip{position:absolute;text-align:center;max-width:200px;padding:2px;font-family:"trebuchet ms",verdana,arial,sans-serif;font-size:12px;background:hsl(-160, 0%, 93.3333333333%);border:1px solid #707070;border-radius:2px;pointer-events:none;z-index:100;}#graph-div .flowchartTitleText{text-anchor:middle;font-size:18px;fill:#000000;}#graph-div :root{--mermaid-font-family:"trebuchet ms",verdana,arial,sans-serif;}</style><g><marker orient="auto" markerHeight="12" markerWidth="12" markerUnits="userSpaceOnUse" refY="5" refX="6" viewBox="0 0 10 10" class="marker flowchart" id="graph-div_flowchart-pointEnd"><path style="stroke-width: 1px; stroke-dasharray: 1px, 0px;" class="arrowMarkerPath" d="M 0 0 L 10 5 L 0 10 z"></path></marker><marker orient="auto" markerHeight="12" markerWidth="12" markerUnits="userSpaceOnUse" refY="5" refX="4.5" viewBox="0 0 10 10" class="marker flowchart" id="graph-div_flowchart-pointStart"><path style="stroke-width: 1px; stroke-dasharray: 1px, 0px;" class="arrowMarkerPath" d="M 0 5 L 10 10 L 10 0 z"></path></marker><marker orient="auto" markerHeight="11" markerWidth="11" markerUnits="userSpaceOnUse" refY="5" refX="11" viewBox="0 0 10 10" class="marker flowchart" id="graph-div_flowchart-circleEnd"><circle style="stroke-width: 1px; stroke-dasharray: 1px, 0px;" class="arrowMarkerPath" r="5" cy="5" cx="5"></circle></marker><marker orient="auto" markerHeight="11" markerWidth="11" markerUnits="userSpaceOnUse" refY="5" refX="-1" viewBox="0 0 10 10" class="marker flowchart" id="graph-div_flowchart-circleStart"><circle style="stroke-width: 1px; stroke-dasharray: 1px, 0px;" class="arrowMarkerPath" r="5" cy="5" cx="5"></circle></marker><marker orient="auto" markerHeight="11" markerWidth="11" markerUnits="userSpaceOnUse" refY="5.2" refX="12" viewBox="0 0 11 11" class="marker cross flowchart" id="graph-div_flowchart-crossEnd"><path style="stroke-width: 2px; stroke-dasharray: 1px, 0px;" class="arrowMarkerPath" d="M 1,1 l 9,9 M 10,1 l -9,9"></path></marker><marker orient="auto" markerHeight="11" markerWidth="11" markerUnits="userSpaceOnUse" refY="5.2" refX="-1" viewBox="0 0 11 11" class="marker cross flowchart" id="graph-div_flowchart-crossStart"><path style="stroke-width: 2px; stroke-dasharray: 1px, 0px;" class="arrowMarkerPath" d="M 1,1 l 9,9 M 10,1 l -9,9"></path></marker><g class="root"><g class="clusters"></g><g class="edgePaths"><path marker-end="url(#graph-div_flowchart-pointEnd)" style="fill:none;" class="edge-thickness-normal edge-pattern-solid flowchart-link LS-A LE-B" id="L-A-B-0" d="M24.433,64L28.6,64C32.767,64,41.1,64,48.55,64C56,64,62.567,64,65.85,64L69.133,64"></path><path marker-end="url(#graph-div_flowchart-pointEnd)" style="fill:none;" class="edge-thickness-normal edge-pattern-solid flowchart-link LS-B LE-C" id="L-B-C-0" d="M98.483,49.547L102.65,44.539C106.817,39.532,115.15,29.516,122.621,24.508C130.092,19.5,136.7,19.5,140.004,19.5L143.308,19.5"></path><path marker-end="url(#graph-div_flowchart-pointEnd)" style="fill:none;" class="edge-thickness-normal edge-pattern-solid flowchart-link LS-B LE-D" id="L-B-D-0" d="M98.483,78.453L102.65,83.461C106.817,88.468,115.15,98.484,122.6,103.492C130.05,108.5,136.617,108.5,139.9,108.5L143.183,108.5"></path><path marker-end="url(#graph-div_flowchart-pointEnd)" style="fill:none;" class="edge-thickness-normal edge-pattern-solid flowchart-link LS-C LE-E" id="L-C-E-0" d="M173.175,19.5L177.363,19.5C181.55,19.5,189.925,19.5,197.716,23.86C205.508,28.22,212.716,36.94,216.319,41.3L219.923,45.66"></path><path marker-end="url(#graph-div_flowchart-pointEnd)" style="fill:none;" class="edge-thickness-normal edge-pattern-solid flowchart-link LS-D LE-E" id="L-D-E-0" d="M173.3,108.5L177.467,108.5C181.633,108.5,189.967,108.5,197.737,104.14C205.508,99.78,212.716,91.06,216.319,86.7L219.923,82.34"></path></g><g class="edgeLabels"><g class="edgeLabel"><g transform="translate(0, 0)" class="label"><foreignObject height="0" width="0"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="edgeLabel"></span></div></foreignObject></g></g><g class="edgeLabel"><g transform="translate(0, 0)" class="label"><foreignObject height="0" width="0"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="edgeLabel"></span></div></foreignObject></g></g><g class="edgeLabel"><g transform="translate(0, 0)" class="label"><foreignObject height="0" width="0"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="edgeLabel"></span></div></foreignObject></g></g><g class="edgeLabel"><g transform="translate(0, 0)" class="label"><foreignObject height="0" width="0"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="edgeLabel"></span></div></foreignObject></g></g><g class="edgeLabel"><g transform="translate(0, 0)" class="label"><foreignObject height="0" width="0"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="edgeLabel"></span></div></foreignObject></g></g></g><g class="nodes"><g transform="translate(12.216667175292969, 64)" data-id="A" data-node="true" id="flowchart-A-504" class="node default default flowchart-label"><rect height="39" width="24.433334350585938" y="-19.5" x="-12.216667175292969" ry="0" rx="0" style="" class="basic label-container"></rect><g transform="translate(-4.716667175292969, -12)" style="" class="label"><rect></rect><foreignObject height="24" width="9.433334350585938"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="nodeLabel">A</span></div></foreignObject></g></g><g transform="translate(86.45833587646484, 64)" data-id="B" data-node="true" id="flowchart-B-505" class="node default default flowchart-label"><rect height="39" width="24.050003051757812" y="-19.5" x="-12.025001525878906" ry="0" rx="0" style="" class="basic label-container"></rect><g transform="translate(-4.525001525878906, -12)" style="" class="label"><rect></rect><foreignObject height="24" width="9.050003051757812"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="nodeLabel">B</span></div></foreignObject></g></g><g transform="translate(160.89167022705078, 19.5)" data-id="C" data-node="true" id="flowchart-C-507" class="node default default flowchart-label"><rect height="39" width="24.566665649414062" y="-19.5" x="-12.283332824707031" ry="0" rx="0" style="" class="basic label-container"></rect><g transform="translate(-4.783332824707031, -12)" style="" class="label"><rect></rect><foreignObject height="24" width="9.566665649414062"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="nodeLabel">C</span></div></foreignObject></g></g><g transform="translate(160.89167022705078, 108.5)" data-id="D" data-node="true" id="flowchart-D-509" class="node default default flowchart-label"><rect height="39" width="24.816665649414062" y="-19.5" x="-12.408332824707031" ry="0" rx="0" style="" class="basic label-container"></rect><g transform="translate(-4.908332824707031, -12)" style="" class="label"><rect></rect><foreignObject height="24" width="9.816665649414062"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="nodeLabel">D</span></div></foreignObject></g></g><g transform="translate(235.08333587646484, 64)" data-id="E" data-node="true" id="flowchart-E-511" class="node default default flowchart-label"><rect height="39" width="23.566665649414062" y="-19.5" x="-11.783332824707031" ry="0" rx="0" style="" class="basic label-container"></rect><g transform="translate(-4.283332824707031, -12)" style="" class="label"><rect></rect><foreignObject height="24" width="8.566665649414062"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="nodeLabel">E</span></div></foreignObject></g></g></g></g></g></svg> 

  ## Dynamic Workflows

  Many workflows aren't static—the number of jobs and their interdependencies aren't known
  beforehand.

  The following worker accepts a count and generates a workflow that fans-out and back in twice,
  using a variable number of dependencies. The key us using `Enum.reduce` to accumulate a workflow
  with interpolated names, i.e. `"a_0"`, `"a_1"`, etc.

  ```elixir
  defmodule MyApp.Dynamic do
    use Oban.Pro.Workers.Workflow

    @impl true
    def process(%{meta: %{"name" => name}}) do
      IO.puts(name)

      :ok
    end

    def insert_workflow(count) when is_integer(count) do
      range = Range.new(0, count)
      a_deps = Enum.map(range, &"a_#{&1}")
      b_deps = Enum.map(range, &"b_#{&1}")

      Workflow.new()
      |> Workflow.add(:a, new(%{}), [])
      |> fan_out(:a, range)
      |> Workflow.add(:b, new(%{}), deps: a_deps)
      |> fan_out(:b, range)
      |> Workflow.add(:c, new(%{}), deps: b_deps)
      |> Oban.insert_all()
    end

    defp fan_out(workflow, base, range) do
      Enum.reduce(range, workflow, fn key, acc ->
        Workflow.add(acc, "#{base}_#{key}", new(%{}), deps: [base])
      end)
    end
  end
  ```

  Calling `MyApp.Dynamic.insert_workflow(3)` generates a workflow that fans out to 3 `a` and 3 `b`
  jobs:

  <svg role="graphics-document document" viewBox="-8 -8 354.29998779296875 233" style="max-width: 600px;" width="100%" id="graph-div" height="400px"><g><marker orient="auto" markerHeight="12" markerWidth="12" markerUnits="userSpaceOnUse" refY="5" refX="6" viewBox="0 0 10 10" class="marker flowchart" id="graph-div_flowchart-pointEnd"><path style="stroke-width: 1px; stroke-dasharray: 1px, 0px;" class="arrowMarkerPath" d="M 0 0 L 10 5 L 0 10 z"></path></marker><marker orient="auto" markerHeight="12" markerWidth="12" markerUnits="userSpaceOnUse" refY="5" refX="4.5" viewBox="0 0 10 10" class="marker flowchart" id="graph-div_flowchart-pointStart"><path style="stroke-width: 1px; stroke-dasharray: 1px, 0px;" class="arrowMarkerPath" d="M 0 5 L 10 10 L 10 0 z"></path></marker><marker orient="auto" markerHeight="11" markerWidth="11" markerUnits="userSpaceOnUse" refY="5" refX="11" viewBox="0 0 10 10" class="marker flowchart" id="graph-div_flowchart-circleEnd"><circle style="stroke-width: 1px; stroke-dasharray: 1px, 0px;" class="arrowMarkerPath" r="5" cy="5" cx="5"></circle></marker><marker orient="auto" markerHeight="11" markerWidth="11" markerUnits="userSpaceOnUse" refY="5" refX="-1" viewBox="0 0 10 10" class="marker flowchart" id="graph-div_flowchart-circleStart"><circle style="stroke-width: 1px; stroke-dasharray: 1px, 0px;" class="arrowMarkerPath" r="5" cy="5" cx="5"></circle></marker><marker orient="auto" markerHeight="11" markerWidth="11" markerUnits="userSpaceOnUse" refY="5.2" refX="12" viewBox="0 0 11 11" class="marker cross flowchart" id="graph-div_flowchart-crossEnd"><path style="stroke-width: 2px; stroke-dasharray: 1px, 0px;" class="arrowMarkerPath" d="M 1,1 l 9,9 M 10,1 l -9,9"></path></marker><marker orient="auto" markerHeight="11" markerWidth="11" markerUnits="userSpaceOnUse" refY="5.2" refX="-1" viewBox="0 0 11 11" class="marker cross flowchart" id="graph-div_flowchart-crossStart"><path style="stroke-width: 2px; stroke-dasharray: 1px, 0px;" class="arrowMarkerPath" d="M 1,1 l 9,9 M 10,1 l -9,9"></path></marker><g class="root"><g class="clusters"></g><g class="edgePaths"><path marker-end="url(#graph-div_flowchart-pointEnd)" style="fill:none;" class="edge-thickness-normal edge-pattern-solid flowchart-link LS-A LE-A1" id="L-A-A1-0" d="M20.371,89L25.215,77.417C30.058,65.833,39.746,42.667,47.873,31.083C56,19.5,62.567,19.5,65.85,19.5L69.133,19.5"></path><path marker-end="url(#graph-div_flowchart-pointEnd)" style="fill:none;" class="edge-thickness-normal edge-pattern-solid flowchart-link LS-A LE-A2" id="L-A-A2-0" d="M24.433,108.5L28.6,108.5C32.767,108.5,41.1,108.5,48.55,108.5C56,108.5,62.567,108.5,65.85,108.5L69.133,108.5"></path><path marker-end="url(#graph-div_flowchart-pointEnd)" style="fill:none;" class="edge-thickness-normal edge-pattern-solid flowchart-link LS-A LE-A3" id="L-A-A3-0" d="M20.371,128L25.215,139.583C30.058,151.167,39.746,174.333,47.873,185.917C56,197.5,62.567,197.5,65.85,197.5L69.133,197.5"></path><path marker-end="url(#graph-div_flowchart-pointEnd)" style="fill:none;" class="edge-thickness-normal edge-pattern-solid flowchart-link LS-A1 LE-B" id="L-A1-B-0" d="M107.25,19.5L111.417,19.5C115.583,19.5,123.917,19.5,132.563,30.268C141.209,41.036,150.168,62.571,154.648,73.339L159.127,84.107"></path><path marker-end="url(#graph-div_flowchart-pointEnd)" style="fill:none;" class="edge-thickness-normal edge-pattern-solid flowchart-link LS-A2 LE-B" id="L-A2-B-0" d="M107.25,108.5L111.417,108.5C115.583,108.5,123.917,108.5,131.367,108.5C138.817,108.5,145.383,108.5,148.667,108.5L151.95,108.5"></path><path marker-end="url(#graph-div_flowchart-pointEnd)" style="fill:none;" class="edge-thickness-normal edge-pattern-solid flowchart-link LS-A3 LE-B" id="L-A3-B-0" d="M107.25,197.5L111.417,197.5C115.583,197.5,123.917,197.5,132.563,186.732C141.209,175.964,150.168,154.429,154.648,143.661L159.127,132.893"></path><path marker-end="url(#graph-div_flowchart-pointEnd)" style="fill:none;" class="edge-thickness-normal edge-pattern-solid flowchart-link LS-B LE-B1" id="L-B-B1-0" d="M177.387,89L182.206,77.417C187.025,65.833,196.662,42.667,204.765,31.083C212.867,19.5,219.433,19.5,222.717,19.5L226,19.5"></path><path marker-end="url(#graph-div_flowchart-pointEnd)" style="fill:none;" class="edge-thickness-normal edge-pattern-solid flowchart-link LS-B LE-B2" id="L-B-B2-0" d="M181.3,108.5L185.467,108.5C189.633,108.5,197.967,108.5,205.417,108.5C212.867,108.5,219.433,108.5,222.717,108.5L226,108.5"></path><path marker-end="url(#graph-div_flowchart-pointEnd)" style="fill:none;" class="edge-thickness-normal edge-pattern-solid flowchart-link LS-B LE-B3" id="L-B-B3-0" d="M177.387,128L182.206,139.583C187.025,151.167,196.662,174.333,204.765,185.917C212.867,197.5,219.433,197.5,222.717,197.5L226,197.5"></path><path marker-end="url(#graph-div_flowchart-pointEnd)" style="fill:none;" class="edge-thickness-normal edge-pattern-solid flowchart-link LS-B1 LE-C" id="L-B1-C-0" d="M263.733,19.5L267.9,19.5C272.067,19.5,280.4,19.5,289.078,30.269C297.756,41.037,306.778,62.574,311.289,73.343L315.8,84.112"></path><path marker-end="url(#graph-div_flowchart-pointEnd)" style="fill:none;" class="edge-thickness-normal edge-pattern-solid flowchart-link LS-B2 LE-C" id="L-B2-C-0" d="M263.733,108.5L267.9,108.5C272.067,108.5,280.4,108.5,287.85,108.5C295.3,108.5,301.867,108.5,305.15,108.5L308.433,108.5"></path><path marker-end="url(#graph-div_flowchart-pointEnd)" style="fill:none;" class="edge-thickness-normal edge-pattern-solid flowchart-link LS-B3 LE-C" id="L-B3-C-0" d="M263.733,197.5L267.9,197.5C272.067,197.5,280.4,197.5,289.078,186.731C297.756,175.963,306.778,154.426,311.289,143.657L315.8,132.888"></path></g><g class="edgeLabels"><g class="edgeLabel"><g transform="translate(0, 0)" class="label"><foreignObject height="0" width="0"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="edgeLabel"></span></div></foreignObject></g></g><g class="edgeLabel"><g transform="translate(0, 0)" class="label"><foreignObject height="0" width="0"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="edgeLabel"></span></div></foreignObject></g></g><g class="edgeLabel"><g transform="translate(0, 0)" class="label"><foreignObject height="0" width="0"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="edgeLabel"></span></div></foreignObject></g></g><g class="edgeLabel"><g transform="translate(0, 0)" class="label"><foreignObject height="0" width="0"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="edgeLabel"></span></div></foreignObject></g></g><g class="edgeLabel"><g transform="translate(0, 0)" class="label"><foreignObject height="0" width="0"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="edgeLabel"></span></div></foreignObject></g></g><g class="edgeLabel"><g transform="translate(0, 0)" class="label"><foreignObject height="0" width="0"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="edgeLabel"></span></div></foreignObject></g></g><g class="edgeLabel"><g transform="translate(0, 0)" class="label"><foreignObject height="0" width="0"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="edgeLabel"></span></div></foreignObject></g></g><g class="edgeLabel"><g transform="translate(0, 0)" class="label"><foreignObject height="0" width="0"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="edgeLabel"></span></div></foreignObject></g></g><g class="edgeLabel"><g transform="translate(0, 0)" class="label"><foreignObject height="0" width="0"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="edgeLabel"></span></div></foreignObject></g></g><g class="edgeLabel"><g transform="translate(0, 0)" class="label"><foreignObject height="0" width="0"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="edgeLabel"></span></div></foreignObject></g></g><g class="edgeLabel"><g transform="translate(0, 0)" class="label"><foreignObject height="0" width="0"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="edgeLabel"></span></div></foreignObject></g></g><g class="edgeLabel"><g transform="translate(0, 0)" class="label"><foreignObject height="0" width="0"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="edgeLabel"></span></div></foreignObject></g></g></g><g class="nodes"><g transform="translate(12.216667175292969, 108.5)" data-id="A" data-node="true" id="flowchart-A-2753" class="node default default flowchart-label"><rect height="39" width="24.433334350585938" y="-19.5" x="-12.216667175292969" ry="0" rx="0" style="" class="basic label-container"></rect><g transform="translate(-4.716667175292969, -12)" style="" class="label"><rect></rect><foreignObject height="24" width="9.433334350585938"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="nodeLabel">A</span></div></foreignObject></g></g><g transform="translate(90.84166717529297, 19.5)" data-id="A1" data-node="true" id="flowchart-A1-2754" class="node default default flowchart-label"><rect height="39" width="32.81666564941406" y="-19.5" x="-16.40833282470703" ry="0" rx="0" style="" class="basic label-container"></rect><g transform="translate(-8.908332824707031, -12)" style="" class="label"><rect></rect><foreignObject height="24" width="17.816665649414062"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="nodeLabel">A1</span></div></foreignObject></g></g><g transform="translate(90.84166717529297, 108.5)" data-id="A2" data-node="true" id="flowchart-A2-2756" class="node default default flowchart-label"><rect height="39" width="32.81666564941406" y="-19.5" x="-16.40833282470703" ry="0" rx="0" style="" class="basic label-container"></rect><g transform="translate(-8.908332824707031, -12)" style="" class="label"><rect></rect><foreignObject height="24" width="17.816665649414062"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="nodeLabel">A2</span></div></foreignObject></g></g><g transform="translate(90.84166717529297, 197.5)" data-id="A3" data-node="true" id="flowchart-A3-2758" class="node default default flowchart-label"><rect height="39" width="32.81666564941406" y="-19.5" x="-16.40833282470703" ry="0" rx="0" style="" class="basic label-container"></rect><g transform="translate(-8.908332824707031, -12)" style="" class="label"><rect></rect><foreignObject height="24" width="17.816665649414062"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="nodeLabel">A3</span></div></foreignObject></g></g><g transform="translate(169.2750015258789, 108.5)" data-id="B" data-node="true" id="flowchart-B-2760" class="node default default flowchart-label"><rect height="39" width="24.050003051757812" y="-19.5" x="-12.025001525878906" ry="0" rx="0" style="" class="basic label-container"></rect><g transform="translate(-4.525001525878906, -12)" style="" class="label"><rect></rect><foreignObject height="24" width="9.050003051757812"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="nodeLabel">B</span></div></foreignObject></g></g><g transform="translate(247.51667022705078, 19.5)" data-id="B1" data-node="true" id="flowchart-B1-2766" class="node default default flowchart-label"><rect height="39" width="32.43333435058594" y="-19.5" x="-16.21666717529297" ry="0" rx="0" style="" class="basic label-container"></rect><g transform="translate(-8.716667175292969, -12)" style="" class="label"><rect></rect><foreignObject height="24" width="17.433334350585938"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="nodeLabel">B1</span></div></foreignObject></g></g><g transform="translate(247.51667022705078, 108.5)" data-id="B2" data-node="true" id="flowchart-B2-2768" class="node default default flowchart-label"><rect height="39" width="32.43333435058594" y="-19.5" x="-16.21666717529297" ry="0" rx="0" style="" class="basic label-container"></rect><g transform="translate(-8.716667175292969, -12)" style="" class="label"><rect></rect><foreignObject height="24" width="17.433334350585938"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="nodeLabel">B2</span></div></foreignObject></g></g><g transform="translate(247.51667022705078, 197.5)" data-id="B3" data-node="true" id="flowchart-B3-2770" class="node default default flowchart-label"><rect height="39" width="32.43333435058594" y="-19.5" x="-16.21666717529297" ry="0" rx="0" style="" class="basic label-container"></rect><g transform="translate(-8.716667175292969, -12)" style="" class="label"><rect></rect><foreignObject height="24" width="17.433334350585938"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="nodeLabel">B3</span></div></foreignObject></g></g><g transform="translate(326.0166702270508, 108.5)" data-id="C" data-node="true" id="flowchart-C-2772" class="node default default flowchart-label"><rect height="39" width="24.566665649414062" y="-19.5" x="-12.283332824707031" ry="0" rx="0" style="" class="basic label-container"></rect><g transform="translate(-4.783332824707031, -12)" style="" class="label"><rect></rect><foreignObject height="24" width="9.566665649414062"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="nodeLabel">C</span></div></foreignObject></g></g></g></g></g></svg>

  ## Using Upstream Results

  Directed dependencies between jobs, paired with the `recorded` option, allow a workflow's
  downstream jobs to fetch the output of upstream jobs.

  To demonstrate, let's make a workflow that combines `all_jobs/2` and
  `c:Oban.Pro.Worker.fetch_recorded/1` to simulate a multi-step API interaction.

  The first worker simulates fetching an authentication token using an `api_key`:

  ```elixir
  defmodule MyApp.WorkerA do
    use Oban.Pro.Workers.Workflow, recorded: true

    @impl true
    def process(%Job{args: %{"api_key" => api_key}}) do
      token =
        api_key
        |> String.graphemes()
        |> Enum.shuffle()
        |> to_string()

      {:ok, token}
    end
  end
  ```

  The second worker fetches the `token` from the first job by calling `all_jobs/2` with the
  `names` option to restrict results to the job named `"a"`, which we'll set while building the
  workflow later.

  ```elixir
  defmodule MyApp.WorkerB do
    use Oban.Pro.Workers.Workflow, recorded: true

    @impl true
    def process(%Job{args: %{"url" => url}} = job) do
      [token_job] = Workflow.all_jobs(job, names: ["a"])

      {:ok, token} = fetch_recorded(token_job)

      {:ok, {token, url}}
    end
  end
  ```

  Then the final worker uses `all_jobs/2` with the `only_deps` option to fetch the results from
  all upstream jobs, then it prints out everything that was fetched.

  ```elixir
  defmodule MyApp.WorkerC do
    use Oban.Pro.Workers.Workflow

    @impl true
    def process(job) do
      job
      |> Workflow.all_jobs(only_deps: true)
      |> Enum.map(&fetch_recorded/1)
      |> IO.inspect()

      :ok
    end
  end
  ```

  The final step is to build a workflow that composes all of the jobs together with names, args,
  and deps:

  ```elixir
  alias MyApp.{WorkerA, WorkerB, WorkerC}

  Workflow.new()
  |> Workflow.add(:a, WorkerA.new(%{api_key: "23kl239bjljlk309af"}))
  |> Workflow.add(:b, WorkerB.new(%{url: "elixir-lang.org"}), deps: [:a])
  |> Workflow.add(:c, WorkerB.new(%{url: "www.erlang.org"}), deps: [:a])
  |> Workflow.add(:d, WorkerB.new(%{url: "getoban.pro"}), deps: [:a])
  |> Workflow.add(:e, WorkerC.new(%{}), deps: [:b, :c, :d])
  |> Oban.insert_all()
  ```

  <svg role="graphics-document document" viewBox="-8 -8 188.816650390625 233" style="max-width: 600px;" width="100%" id="graph-div" height="400px"><g><marker orient="auto" markerHeight="12" markerWidth="12" markerUnits="userSpaceOnUse" refY="5" refX="6" viewBox="0 0 10 10" class="marker flowchart" id="graph-div_flowchart-pointEnd"><path style="stroke-width: 1px; stroke-dasharray: 1px, 0px;" class="arrowMarkerPath" d="M 0 0 L 10 5 L 0 10 z"></path></marker><marker orient="auto" markerHeight="12" markerWidth="12" markerUnits="userSpaceOnUse" refY="5" refX="4.5" viewBox="0 0 10 10" class="marker flowchart" id="graph-div_flowchart-pointStart"><path style="stroke-width: 1px; stroke-dasharray: 1px, 0px;" class="arrowMarkerPath" d="M 0 5 L 10 10 L 10 0 z"></path></marker><marker orient="auto" markerHeight="11" markerWidth="11" markerUnits="userSpaceOnUse" refY="5" refX="11" viewBox="0 0 10 10" class="marker flowchart" id="graph-div_flowchart-circleEnd"><circle style="stroke-width: 1px; stroke-dasharray: 1px, 0px;" class="arrowMarkerPath" r="5" cy="5" cx="5"></circle></marker><marker orient="auto" markerHeight="11" markerWidth="11" markerUnits="userSpaceOnUse" refY="5" refX="-1" viewBox="0 0 10 10" class="marker flowchart" id="graph-div_flowchart-circleStart"><circle style="stroke-width: 1px; stroke-dasharray: 1px, 0px;" class="arrowMarkerPath" r="5" cy="5" cx="5"></circle></marker><marker orient="auto" markerHeight="11" markerWidth="11" markerUnits="userSpaceOnUse" refY="5.2" refX="12" viewBox="0 0 11 11" class="marker cross flowchart" id="graph-div_flowchart-crossEnd"><path style="stroke-width: 2px; stroke-dasharray: 1px, 0px;" class="arrowMarkerPath" d="M 1,1 l 9,9 M 10,1 l -9,9"></path></marker><marker orient="auto" markerHeight="11" markerWidth="11" markerUnits="userSpaceOnUse" refY="5.2" refX="-1" viewBox="0 0 11 11" class="marker cross flowchart" id="graph-div_flowchart-crossStart"><path style="stroke-width: 2px; stroke-dasharray: 1px, 0px;" class="arrowMarkerPath" d="M 1,1 l 9,9 M 10,1 l -9,9"></path></marker><g class="root"><g class="clusters"></g><g class="edgePaths"><path marker-end="url(#graph-div_flowchart-pointEnd)" style="fill:none;" class="edge-thickness-normal edge-pattern-solid flowchart-link LS-A LE-B" id="L-A-B-0" d="M20.371,89L25.215,77.417C30.058,65.833,39.746,42.667,47.937,31.083C56.128,19.5,62.822,19.5,66.169,19.5L69.517,19.5"></path><path marker-end="url(#graph-div_flowchart-pointEnd)" style="fill:none;" class="edge-thickness-normal edge-pattern-solid flowchart-link LS-A LE-C" id="L-A-C-0" d="M24.433,108.5L28.6,108.5C32.767,108.5,41.1,108.5,48.571,108.5C56.042,108.5,62.65,108.5,65.954,108.5L69.258,108.5"></path><path marker-end="url(#graph-div_flowchart-pointEnd)" style="fill:none;" class="edge-thickness-normal edge-pattern-solid flowchart-link LS-A LE-D" id="L-A-D-0" d="M20.371,128L25.215,139.583C30.058,151.167,39.746,174.333,47.873,185.917C56,197.5,62.567,197.5,65.85,197.5L69.133,197.5"></path><path marker-end="url(#graph-div_flowchart-pointEnd)" style="fill:none;" class="edge-thickness-normal edge-pattern-solid flowchart-link LS-B LE-E" id="L-B-E-0" d="M98.867,19.5L103.097,19.5C107.328,19.5,115.789,19.5,124.469,30.267C133.15,41.034,142.05,62.568,146.5,73.335L150.95,84.102"></path><path marker-end="url(#graph-div_flowchart-pointEnd)" style="fill:none;" class="edge-thickness-normal edge-pattern-solid flowchart-link LS-C LE-E" id="L-C-E-0" d="M99.125,108.5L103.313,108.5C107.5,108.5,115.875,108.5,123.346,108.5C130.817,108.5,137.383,108.5,140.667,108.5L143.95,108.5"></path><path marker-end="url(#graph-div_flowchart-pointEnd)" style="fill:none;" class="edge-thickness-normal edge-pattern-solid flowchart-link LS-D LE-E" id="L-D-E-0" d="M99.25,197.5L103.417,197.5C107.583,197.5,115.917,197.5,124.533,186.733C133.15,175.966,142.05,154.432,146.5,143.665L150.95,132.898"></path></g><g class="edgeLabels"><g class="edgeLabel"><g transform="translate(0, 0)" class="label"><foreignObject height="0" width="0"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="edgeLabel"></span></div></foreignObject></g></g><g class="edgeLabel"><g transform="translate(0, 0)" class="label"><foreignObject height="0" width="0"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="edgeLabel"></span></div></foreignObject></g></g><g class="edgeLabel"><g transform="translate(0, 0)" class="label"><foreignObject height="0" width="0"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="edgeLabel"></span></div></foreignObject></g></g><g class="edgeLabel"><g transform="translate(0, 0)" class="label"><foreignObject height="0" width="0"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="edgeLabel"></span></div></foreignObject></g></g><g class="edgeLabel"><g transform="translate(0, 0)" class="label"><foreignObject height="0" width="0"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="edgeLabel"></span></div></foreignObject></g></g><g class="edgeLabel"><g transform="translate(0, 0)" class="label"><foreignObject height="0" width="0"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="edgeLabel"></span></div></foreignObject></g></g></g><g class="nodes"><g transform="translate(12.216667175292969, 108.5)" data-id="A" data-node="true" id="flowchart-A-553" class="node default default flowchart-label"><rect height="39" width="24.433334350585938" y="-19.5" x="-12.216667175292969" ry="0" rx="0" style="" class="basic label-container"></rect><g transform="translate(-4.716667175292969, -12)" style="" class="label"><rect></rect><foreignObject height="24" width="9.433334350585938"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="nodeLabel">A</span></div></foreignObject></g></g><g transform="translate(86.84166717529297, 19.5)" data-id="B" data-node="true" id="flowchart-B-554" class="node default default flowchart-label"><rect height="39" width="24.050003051757812" y="-19.5" x="-12.025001525878906" ry="0" rx="0" style="" class="basic label-container"></rect><g transform="translate(-4.525001525878906, -12)" style="" class="label"><rect></rect><foreignObject height="24" width="9.050003051757812"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="nodeLabel">B</span></div></foreignObject></g></g><g transform="translate(86.84166717529297, 108.5)" data-id="C" data-node="true" id="flowchart-C-556" class="node default default flowchart-label"><rect height="39" width="24.566665649414062" y="-19.5" x="-12.283332824707031" ry="0" rx="0" style="" class="basic label-container"></rect><g transform="translate(-4.783332824707031, -12)" style="" class="label"><rect></rect><foreignObject height="24" width="9.566665649414062"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="nodeLabel">C</span></div></foreignObject></g></g><g transform="translate(86.84166717529297, 197.5)" data-id="D" data-node="true" id="flowchart-D-558" class="node default default flowchart-label"><rect height="39" width="24.816665649414062" y="-19.5" x="-12.408332824707031" ry="0" rx="0" style="" class="basic label-container"></rect><g transform="translate(-4.908332824707031, -12)" style="" class="label"><rect></rect><foreignObject height="24" width="9.816665649414062"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="nodeLabel">D</span></div></foreignObject></g></g><g transform="translate(161.03333282470703, 108.5)" data-id="E" data-node="true" id="flowchart-E-560" class="node default default flowchart-label"><rect height="39" width="23.566665649414062" y="-19.5" x="-11.783332824707031" ry="0" rx="0" style="" class="basic label-container"></rect><g transform="translate(-4.283332824707031, -12)" style="" class="label"><rect></rect><foreignObject height="24" width="8.566665649414062"><div xmlns="http://www.w3.org/1999/xhtml" style="display: inline-block; white-space: nowrap;"><span class="nodeLabel">E</span></div></foreignObject></g></g></g></g></g></svg>

  When the workflow runs the final step, `e`, prints out something like the following:

  ```elixir
  {"93l2jlj3kl90baf2k3", "elixir-lang.org"}
  {"93l2jlj3kl90baf2k3", "www.erlang.org"}
  {"93l2jlj3kl90baf2k3", "getoban.pro"}
  ```

  ## Customizing Workflows

  Workflows use conservative defaults for safe, and relatively quick, dependency resolution. You
  can customize the safety checks by providing a few top-level options:

  * `ignore_cancelled` — regard `cancelled` dependencies as completed rather than cancelling
    remaining jobs in the workflow. Defaults to `false`.

  * `ignore_discarded` — regard `discarded` dependencies as completed rather than cancelling
    remaining jobs in the workflow. Defaults to `false`.

  * `ignore_deleted` — regard `deleted` (typically pruned) dependencies as completed rather
    cancelling remaining jobs in workflow. Defaults to `false`.

  * `workflow_name` — an optional name to describe the purpose of the workflow, beyond the
    individual jobs in it.

  The following example creates a workflow with all of the available options:

  ```elixir
  alias Oban.Pro.Workers.Workflow

  workflow = Workflow.new(
    ignore_cancelled: true,
    ignore_deleted: true,
    ignore_discarded: true,
    workflow_name: "special_purpose"
  )
  ```

  Options may also be applied to individual workflow jobs For example, configure a single job to
  ignore `cancelled` dependencies, another to ignore `discarded`, and another to ignore `deleted`:

  ```elixir
  Workflow.new()
  |> Workflow.add(:a, MyWorkflow.new(%{}))
  |> Workflow.add(:b, MyWorkflow.new(%{}, deps: [:a], ignore_cancelled: true))
  |> Workflow.add(:c, MyWorkflow.new(%{}, deps: [:b], ignore_discarded: true))
  |> Workflow.add(:d, MyWorkflow.new(%{}, deps: [:c], ignore_deleted: true))
  ```

  Dependency resolution relies on jobs lingering in the database after execution. If your system
  prunes job dependencies then the workflow may never complete. Set `ignore_deleted: true` on your
  workflows to override this behaviour.

  ## Handling Cancellations

  Workflow jobs are automatically `cancelled` when their upstream dependencies are `cancelled`,
  `discarded`, or `deleted` (unless specifically overridden using the `ignore_*` options as
  described earlier). Those workflow jobs are cancelled before they're executing, which means
  standard `c:Oban.Pro.Worker.after_process/3` hooks won't be called. Instead, there's an
  optional `c:after_cancelled/2` callback specifically for workflows. 

  Here's a trivial `after_cancelled` hook that logs a warning when a workflow job is cancelled:

  ```elixir
  def MyApp.Workflow do
    use Oban.Pro.Workers.Workflow

    require Logger

    @impl true
    def after_cancelled(reason, job) do
      Logger.warn("Workflow job #{job.id} cancelled because a dependency was #{reason}")
    end
  ```

  ## Appending Workflow Jobs

  Sometimes all jobs aren't known when the workflow is created. In that case, you can add more
  jobs with optional dependency checking using `append/2`. An appended workflow starts with one or
  more jobs, which reuses the original workflow id, and optionally builds a set of dependencies
  for checking.

  In this example we disable deps checking with `check_deps: false`:

  ```elixir
  defmodule MyApp.WorkflowWorker do
    use Oban.Pro.Workers.Workflow

    @impl true
    def process(%Job{} = job) do
      jobs =
        job
        |> Workflow.append(check_deps: false)
        |> Workflow.add(:d, WorkerD.new(%{}), deps: [:a])
        |> Workflow.add(:e, WorkerE.new(%{}), deps: [:b])
        |> Workflow.add(:f, WorkerF.new(%{}), deps: [:c])
        |> Oban.insert_all()

      {:ok, jobs}
    end
  end
  ```

  The new jobs specify deps on preexisting jobs named `:a`, `:b`, and `:c`, but there isn't any
  guarantee those jobs actually exist. That could lead to an incomplete workflow where the new
  jobs may never complete.

  To be safe and check jobs while appending we'll fetch all of the previous jobs and feed them in:

  ```elixir
  defmodule MyApp.WorkflowWorker do
    use Oban.Pro.Workers.Workflow

    @impl true
    def process(%Job{} = job) do
      {:ok, jobs} =
        MyApp.Repo.transaction(fn ->
          job
          |> Workflow.stream_jobs()
          |> Enum.to_list()
        end)

      jobs
      |> Workflow.append()
      |> Workflow.add(:d, WorkerD.new(%{}), deps: [:a])
      |> Workflow.add(:e, WorkerE.new(%{}), deps: [:b])
      |> Workflow.add(:f, WorkerF.new(%{}), deps: [:c])
      |> Oban.insert_all()

      :ok
    end
  end
  ```

  Now there isn't any risk of an incomplete workflow from missing dependencies, at the expense of
  loading some extraneous jobs.

  ## Fetching Workflow Jobs

  Workflow jobs are tied together through `meta` attributes. The `all_jobs/2` function uses those
  attributes to load other jobs in a workflow. This is particularly useful from a worker's
  `process/1` function. For example, to fetch all of the jobs in a workflow:

  ```elixir
  defmodule MyApp.Workflow do
    use Oban.Pro.Workers.Workflow

    @impl Workflow
    def process(%Job{} = job) do
      job
      |> Workflow.all_jobs()
      |> do_things_with_jobs()

      :ok
    end
  end
  ```

  It's also possible to scope fetching to only dependencies of the current job with `only_deps`:

  ```elixir
  deps = Workflow.all_jobs(job, only_deps: true)
  ```

  Or, only fetch a single explicit dependency by name with `names`:

  ```elixir
  [dep_job] = Workflow.all_jobs(job, names: [:a])
  ```

  For large workflows it may be inefficient to load all jobs in memory at once. In that case, you
  can the `stream_jobs/2` function to fetch jobs lazily. For example, to stream all of the
  `completed` jobs in a workflow:

  ```elixir
  defmodule MyApp.Workflow do
    use Oban.Pro.Workers.Workflow

    @impl Workflow
    def process(%Job{} = job) do
      {:ok, workflow_jobs} =
        MyApp.Repo.transaction(fn ->
          job
          |> Workflow.stream_jobs()
          |> Stream.filter(& &1.state == "completed")
          |> Enum.to_list()
        end)

      do_things_with_jobs(workflow_jobs)

      :ok
    end
  end
  ```

  Streaming is provided by Ecto's `Repo.stream`, and it must take place within a transaction.
  Using a stream lets you control the number of jobs loaded from the database, minimizing memory
  usage for large workflows.

  ## Generating Workflow IDs

  By default `workflow_id` is a time-ordered random [UUIDv7][uuid]. This is more than sufficient
  to ensure that workflows are unique for any period of time. However, if you require more control
  you can override `workflow_id` generation at the worker level, or pass a value directly to the
  `c:new_workflow/1` function.

  To override the `workflow_id` for a particular workflow you override the `c:gen_id/0` callback:

  ```elixir
  defmodule MyApp.Workflow do
    use Oban.Pro.Workers.Workflow

    # Generate a 24 character long random string instead
    @impl true
    def gen_id do
      24
      |> :crypto.strong_rand_bytes()
      |> Base.encode64()
    end
    ...
  end
  ```

  The `c:gen_id/0` callback works for random/non-deterministic id generation. If you'd prefer to
  use a deterministic id instead you can pass the `workflow_id` in as an option to
  `c:new_workflow/1`:

  ```elixir
  MyApp.Workflow.new_workflow(workflow_id: "custom-id")
  ```

  Using this technique you can verify the `workflow_id` in tests or append to the workflow
  manually after it was originally created.

  [uuid]: https://datatracker.ietf.org/doc/html/draft-peabody-dispatch-new-uuid-format-04#section-5.2


  ## Visualizing Workflows

  Workflows are a type of [Directed Acyclic Graph][dag], also known as a DAG. That means we can
  describe a workflow as a graph of jobs and dependencies, where execution flows between jobs. By
  converting the workflow into [DOT][dot] notation, a standard graph description language, we can
  render visualizations!

  Dot generation relies on [libgraph][libgraph], which is an optional dependency. You'll need to
  specify it as a dependency before generating dot output:

  ```elixir
  def deps do
    [{:libgraph, "~> 0.7"}]
  end
  ```

  Once you've installed `libgraph`, we can use `to_dot/1` to convert a workflow. As with
  `new_workflow` and `add`, all workflow workers define a `to_dot/1` function that takes a
  workflow and returns a dot formatted string. For example, calling `to_dot/1` with the account
  archiving workflow from above:

  ```elixir
  FinalReceipt.to_dot(archive_account_workflow(123))
  ```

  Generates the following dot output, where each vertex is a combination of the job's name in the
  workflow and its worker module:

  ```text
  strict digraph {
      "delete (MyApp.DeleteAccount)"
      "backup_1 (MyApp.BackupPost)"
      "backup_2 (MyApp.BackupPost)"
      "backup_3 (MyApp.BackupPost)"
      "receipt (MyApp.FinalReceipt)"
      "email_1 (MyApp.EmailSubscriber)"
      "email_2 (MyApp.EmailSubscriber)"
      "backup_1 (MyApp.BackupPost)" -> "delete (MyApp.DeleteAccount)" [weight=1]
      "backup_2 (MyApp.BackupPost)" -> "delete (MyApp.DeleteAccount)" [weight=1]
      "backup_3 (MyApp.BackupPost)" -> "delete (MyApp.DeleteAccount)" [weight=1]
      "receipt (MyApp.FinalReceipt)" -> "backup_1 (MyApp.BackupPost)" [weight=1]
      "receipt (MyApp.FinalReceipt)" -> "backup_2 (MyApp.BackupPost)" [weight=1]
      "receipt (MyApp.FinalReceipt)" -> "backup_3 (MyApp.BackupPost)" [weight=1]
      "receipt (MyApp.FinalReceipt)" -> "email_1 (MyApp.EmailSubscriber)" [weight=1]
      "receipt (MyApp.FinalReceipt)" -> "email_2 (MyApp.EmailSubscriber)" [weight=1]
      "email_1 (MyApp.EmailSubscriber)" -> "delete (MyApp.DeleteAccount)" [weight=1]
      "email_2 (MyApp.EmailSubscriber)" -> "delete (MyApp.DeleteAccount)" [weight=1]
  }
  ```

  Now we can take that dot output and render it using a tool like [graphviz][gv]. The following
  example function accepts a workflow and renders it out as an SVG:

  ```elixir
  defmodule WorkflowRenderer do
    alias Oban.Pro.Workers.Workflow

    def render(workflow) do
      dot_path = "workflow.dot"
      svg_path = "workflow.svg"

      File.write!(dot_path, Workflow.to_dot(workflow))

      System.cmd("dot", ["-T", "svg", "-o", svg_path, dot_path])
    end
  end
  ```

  With [graphviz][gv] installed, that will generate a SVG of the workflow:

  <svg viewBox="0 0 1381.58 188" xmlns="http://www.w3.org/2000/svg"><g class="graph"><path fill="#fff" stroke="transparent" d="M0 188V0h1381.58v188H0z"/><g class="node" transform="translate(4 184)"><ellipse fill="none" stroke="#000" cx="663.44" cy="-18" rx="122.68" ry="18"/><text text-anchor="middle" x="663.44" y="-14.3" font-family="Times,serif" font-size="14">delete (MyApp.DeleteAccount)</text></g><g class="node" transform="translate(4 184)"><ellipse fill="none" stroke="#000" cx="125.44" cy="-90" rx="125.38" ry="18"/><text text-anchor="middle" x="125.44" y="-86.3" font-family="Times,serif" font-size="14">backup_1 (MyApp.BackupPost)</text></g><g class="edge" transform="translate(4 184)"><path fill="none" stroke="#000" d="M214.88-77.36c96.49 12.55 249.69 32.48 349.69 45.5"/><path stroke="#000" d="M565.21-35.31l9.47 4.76-10.37 2.18.9-6.94z"/></g><g class="node" transform="translate(4 184)"><ellipse fill="none" stroke="#000" cx="394.44" cy="-90" rx="125.38" ry="18"/><text text-anchor="middle" x="394.44" y="-86.3" font-family="Times,serif" font-size="14">backup_2 (MyApp.BackupPost)</text></g><g class="edge" transform="translate(4 184)"><path fill="none" stroke="#000" d="M452.15-73.98C494.34-63 551.7-48.08 596.01-36.55"/><path stroke="#000" d="M597.03-39.9l8.8 5.91-10.56.87 1.76-6.78z"/></g><g class="node" transform="translate(4 184)"><ellipse fill="none" stroke="#000" cx="663.44" cy="-90" rx="125.38" ry="18"/><text text-anchor="middle" x="663.44" y="-86.3" font-family="Times,serif" font-size="14">backup_3 (MyApp.BackupPost)</text></g><g class="edge" transform="translate(4 184)"><path fill="none" stroke="#000" d="M663.44-71.7v25.59"/><path stroke="#000" d="M666.94-46.1l-3.5 10-3.5-10h7z"/></g><g class="node" transform="translate(4 184)"><ellipse fill="none" stroke="#000" cx="663.44" cy="-162" rx="118.08" ry="18"/><text text-anchor="middle" x="663.44" y="-158.3" font-family="Times,serif" font-size="14">receipt (MyApp.FinalReceipt)</text></g><g class="edge" transform="translate(4 184)"><path fill="none" stroke="#000" d="M576.7-149.71c-95.97 12.48-250.38 32.57-351.35 45.71"/><path stroke="#000" d="M225.51-100.49l-10.36-2.18 9.46-4.76.9 6.94z"/></g><g class="edge" transform="translate(4 184)"><path fill="none" stroke="#000" d="M606.39-146.15c-42.15 10.96-99.7 25.94-144.2 37.52"/><path stroke="#000" d="M462.89-105.2l-10.56-.87 8.8-5.9 1.76 6.77z"/></g><g class="edge" transform="translate(4 184)"><path fill="none" stroke="#000" d="M663.44-143.7v25.59"/><path stroke="#000" d="M666.94-118.1l-3.5 10-3.5-10h7z"/></g><g class="node" transform="translate(4 184)"><ellipse fill="none" stroke="#000" cx="944.44" cy="-90" rx="137.28" ry="18"/><text text-anchor="middle" x="944.44" y="-86.3" font-family="Times,serif" font-size="14">email_1 (MyApp.EmailSubscriber)</text></g><g class="edge" transform="translate(4 184)"><path fill="none" stroke="#000" d="M722.35-146.33c44.17 11.01 104.81 26.11 151.56 37.76"/><path stroke="#000" d="M874.81-111.95l8.86 5.81-10.55.98 1.69-6.79z"/></g><g class="node" transform="translate(4 184)"><ellipse fill="none" stroke="#000" cx="1236.44" cy="-90" rx="137.28" ry="18"/><text text-anchor="middle" x="1236.44" y="-86.3" font-family="Times,serif" font-size="14">email_2 (MyApp.EmailSubscriber)</text></g><g class="edge" transform="translate(4 184)"><path fill="none" stroke="#000" d="M752.66-150.1c101.88 12.45 268.46 32.8 377.11 46.07"/><path stroke="#000" d="M1130.27-107.5l9.5 4.69-10.35 2.26.85-6.95z"/></g><g class="edge" transform="translate(4 184)"><path fill="none" stroke="#000" d="M883.47-73.81c-44.37 11.05-104.5 26.03-150.69 37.54"/><path stroke="#000" d="M733.4-32.82l-10.55-.98 8.85-5.81 1.7 6.79z"/></g><g class="edge" transform="translate(4 184)"><path fill="none" stroke="#000" d="M1139.89-77.2L764.77-31.38"/><path stroke="#000" d="M765.05-27.89l-10.35-2.26 9.5-4.69.85 6.95z"/></g></g></svg>

  Looking at the visualized graph we can clearly see how the workflow starts with a single
  `render` job, fans-out to multiple `email` and `backup` jobs, and finally fans-in to the
  `delete` job—exactly as we planned!

  [dag]: https://en.wikipedia.org/wiki/Directed_acyclic_graph
  [dot]: https://en.wikipedia.org/wiki/DOT_%28graph_description_language%29
  [libgraph]: https://github.com/bitwalker/libgraph
  [gv]: https://graphviz.org
  """

  import Ecto.Query, only: [group_by: 3, order_by: 2, select: 3, where: 3]

  alias Ecto.Changeset
  alias Oban.{Job, Repo, Worker}

  @type add_option :: {:deps, [name()]}

  @type append_option :: new_option() | {:check_deps, boolean()}

  @type cancel_reason :: :deleted | :discarded | :cancelled

  @type chan :: Job.changeset()

  @type new_option ::
          {:ignore_cancelled, boolean()}
          | {:ignore_deleted, boolean()}
          | {:ignore_discarded, boolean()}
          | {:workflow_id, String.t()}
          | {:workflow_name, String.t()}

  @type fetch_option ::
          {:log, Logger.level()}
          | {:names, [name()]}
          | {:only_deps, boolean()}
          | {:timeout, timeout()}

  @type name :: atom() | String.t()

  @type t :: %__MODULE__{
          id: String.t(),
          changesets: [chan()],
          check_deps: boolean(),
          names: MapSet.t(),
          opts: map()
        }

  @doc """
  Instantiate a new workflow struct with a unique workflow id.

  Delegates to `new/1` and uses the module's `c:gen_id/0` to generate the workflow id.
  """
  @callback new_workflow(opts :: [new_option()]) :: t()

  @doc """
  Called after a workflow job is cancelled due to upstream jobs being `cancelled`, `deleted`, or
  `discarded`.

  This callback is _only_ called when a job is cancelled because of an upstream dependency. It is
  _never_ called after normal job execution. For that, use `c:Oban.Pro.Worker.after_process/3`.
  """
  @callback after_cancelled(cancel_reason(), job :: Job.t()) :: :ok

  @doc """
  Delegates to `add/4`.
  """
  @callback add(flow :: t(), name :: name(), changeset :: chan(), opts :: [add_option()]) :: t()

  @doc """
  Delegates to `append/2`.
  """
  @callback append_workflow(jobs :: Job.t() | [Job.t()], [append_option()]) :: t()

  @doc """
  Generate a unique string to identify the workflow.

  Defaults to a 128bit UUIDv7.

  ## Examples

  Generate a workflow id using random bytes instead of a UUID:

      @impl Workflow
      def gen_id do
        24
        |> :crypto.strong_rand_bytes()
        |> Base.encode64()
      end
  """
  @callback gen_id() :: String.t()

  @doc """
  Delegates to `to_dot/1`.
  """
  @callback to_dot(flow :: t()) :: String.t()

  @doc """
  Delegates to `all_jobs/2`.
  """
  @callback all_workflow_jobs(job :: Job.t(), [fetch_option()]) :: [Job.t()]

  @doc """
  Delegates to `stream_jobs/2`.
  """
  @callback stream_workflow_jobs(job :: Job.t(), [fetch_option()]) :: Enum.t()

  @optional_callbacks after_cancelled: 2

  defstruct [:id, changesets: [], check_deps: true, names: MapSet.new(), opts: %{}]

  defmacro __using__(opts) do
    quote location: :keep do
      use Oban.Pro.Worker, unquote(opts)

      alias Oban.Pro.Workers.Workflow

      @behaviour Workflow

      defguardp is_name(name) when (is_atom(name) and not is_nil(name)) or is_binary(name)

      @impl Workflow
      def new_workflow(opts \\ []) when is_list(opts) do
        opts
        |> Keyword.put_new(:workflow_id, gen_id())
        |> Workflow.new()
      end

      @impl Workflow
      def append_workflow(jobs, opts \\ []) do
        Workflow.append(jobs, opts)
      end

      @impl Workflow
      def add(%_{} = workflow, name, %Changeset{} = changeset, opts \\ []) when is_name(name) do
        Workflow.add(workflow, name, changeset, opts)
      end

      @impl Workflow
      def gen_id do
        Workflow.gen_id()
      end

      @impl Workflow
      def to_dot(workflow) do
        Workflow.to_dot(workflow)
      end

      @impl Workflow
      def stream_workflow_jobs(%Job{} = job, opts \\ []) do
        Workflow.stream_jobs(job, opts)
      end

      @impl Workflow
      def all_workflow_jobs(%Job{} = job, opts \\ []) do
        Workflow.all_jobs(job, opts)
      end

      @impl Worker
      def perform(%Job{} = job) do
        opts = __opts__()

        with {:ok, job} <- Oban.Pro.Worker.before_process(job, opts) do
          job
          |> Workflow.maybe_process(__MODULE__)
          |> Oban.Pro.Worker.after_process(job, opts)
        end
      end

      defoverridable Workflow
    end
  end

  @hold_date ~U[3000-01-01 00:00:00.000000Z]

  # Processing

  @doc false
  def maybe_process(%{meta: meta} = job, module) do
    if is_map_key(meta, "workflow_id") and not is_map_key(meta, "on_hold") do
      legacy_process(job, module)
    else
      module.process(job)
    end
  end

  @legacy_meta %{
    ignore_cancelled: false,
    ignore_deleted: false,
    ignore_discarded: false,
    waiting_delay: :timer.seconds(1),
    waiting_limit: 10,
    waiting_snooze: 5
  }

  # This is only necessary for backward compatibility. Remove in Pro v1.5.
  defp legacy_process(job, module, waiting_count \\ 0) do
    meta = for {key, val} <- @legacy_meta, into: %{}, do: {key, job.meta[to_string(key)] || val}

    case legacy_check_deps(job) do
      :completed ->
        module.process(job)

      :available ->
        {:snooze, meta.waiting_snooze}

      :executing ->
        if waiting_count >= meta.waiting_limit do
          {:snooze, meta.waiting_snooze}
        else
          Process.sleep(meta.waiting_delay)

          legacy_process(job, module, waiting_count + 1)
        end

      {:scheduled, scheduled_at} ->
        seconds =
          scheduled_at
          |> DateTime.diff(DateTime.utc_now())
          |> max(meta.waiting_snooze)

        {:snooze, seconds}

      :cancelled ->
        if meta.ignore_cancelled do
          module.process(job)
        else
          {:cancel, "upstream deps cancelled, workflow will never complete"}
        end

      :discarded ->
        if meta.ignore_discarded do
          module.process(job)
        else
          {:cancel, "upstream deps discarded, workflow will never complete"}
        end

      :deleted ->
        if meta.ignore_deleted do
          module.process(job)
        else
          {:cancel, "upstream deps deleted, workflow will never complete"}
        end
    end
  end

  defp legacy_check_deps(%{conf: conf, meta: %{"deps" => [_ | _]}} = job) do
    %{"deps" => deps, "workflow_id" => workflow_id} = job.meta

    deps_count = length(deps)

    query =
      Job
      |> where([j], fragment("? @> ?", j.meta, ^%{workflow_id: workflow_id}))
      |> where([j], fragment("?->>'name'", j.meta) in ^deps)
      |> group_by([j], j.state)
      |> select([j], {j.state, count(j.id), max(j.scheduled_at)})

    conf
    |> Repo.all(query)
    |> Map.new(fn {state, count, sc_at} -> {state, {count, sc_at}} end)
    |> case do
      %{"completed" => {^deps_count, _}} -> :completed
      %{"scheduled" => {_, scheduled_at}} -> {:scheduled, scheduled_at}
      %{"retryable" => {_, scheduled_at}} -> {:scheduled, scheduled_at}
      %{"executing" => _} -> :executing
      %{"available" => _} -> :available
      %{"cancelled" => _} -> :cancelled
      %{"discarded" => _} -> :discarded
      %{} -> :deleted
    end
  end

  defp legacy_check_deps(_job), do: :completed

  # Public Interface

  @doc """
  Instantiate a new workflow struct with a unique workflow id.

  ## Examples

  Create a standard workflow without any options:

      Workflow.new()

  Create a workflow with a custom name:

      Workflow.new(workflow_name: "logistics")

  Create a workflow with a static id and some options:

      Workflow.new(workflow_id: "workflow-id", ignore_cancelled: true, ignore_discarded: true)
  """
  @spec new(opts :: [new_option()]) :: t()
  def new(opts \\ []) do
    opts =
      opts
      |> Keyword.put(:workflow, true)
      |> Keyword.put_new_lazy(:workflow_id, &gen_id/0)
      |> Map.new()

    %__MODULE__{id: opts.workflow_id, opts: opts}
  end

  @doc """
  Add a named job to the workflow along with optional dependencies.

  ## Examples

  Add jobs to a workflow with dependencies:

      Workflow.new()
      |> Workflow.add(:a, MyApp.WorkerA.new(%{id: id}))
      |> Workflow.add(:b, MyApp.WorkerB.new(%{id: id}), deps: [:a])
      |> Workflow.add(:c, MyApp.WorkerC.new(%{id: id}), deps: [:a])
      |> Workflow.add(:d, MyApp.WorkerC.new(%{id: id}), deps: [:b, :c])
  """
  @spec add(flow :: t(), name :: name(), changeset :: chan(), opts :: [add_option()]) :: t()
  def add(%_{} = workflow, name, %Changeset{} = changeset, opts \\ []) do
    {deps, opts} = Keyword.pop(opts, :deps, [])

    name = to_string(name)
    deps = Enum.map(deps, &to_string/1)

    prevent_dupe!(workflow, name)
    ensure_workflow!(name, changeset)

    if workflow.check_deps, do: confirm_deps!(workflow, deps)

    meta =
      changeset
      |> Changeset.get_change(:meta, %{})
      |> Map.put(:deps, deps)
      |> Map.put(:name, name)
      |> Map.put(:on_hold, Enum.any?(deps))
      |> Map.put(:workflow_id, workflow.id)
      |> Map.merge(workflow.opts)
      |> Map.merge(Map.new(opts))

    meta =
      if Changeset.get_field(changeset, :state) == "scheduled" do
        orig_at =
          changeset
          |> Changeset.get_change(:scheduled_at)
          |> DateTime.to_unix(:microsecond)

        Map.put(meta, :orig_scheduled_at, orig_at)
      else
        meta
      end

    changeset =
      if Enum.any?(deps) do
        changeset
        |> Changeset.put_change(:meta, meta)
        |> Changeset.put_change(:state, "scheduled")
        |> Changeset.put_change(:scheduled_at, @hold_date)
      else
        Changeset.put_change(changeset, :meta, meta)
      end

    changesets = workflow.changesets ++ [changeset]

    %{workflow | changesets: changesets, names: MapSet.put(workflow.names, name)}
  end

  @doc """
  Instantiate a new workflow from an existing workflow job or jobs.

  ## Examples

  Append to a workflow seeded with all other jobs in the workflow:

      jobs
      |> Workflow.append()
      |> Workflow.add(:d, WorkerD.new(%{}), deps: [:a])
      |> Workflow.add(:e, WorkerE.new(%{}), deps: [:b])
      |> Oban.insert_all()

  Append to a workflow from a single job and bypass checking deps:

      job
      |> Workflow.append(check_deps: false)
      |> Workflow.add(:d, WorkerD.new(%{}), deps: [:a])
      |> Workflow.add(:e, WorkerE.new(%{}), deps: [:b])
      |> Oban.insert_all()
  """
  @spec append(jobs :: Job.t() | [Job.t()], [append_option()]) :: t()
  def append(jobs, opts \\ [])

  def append([%Job{meta: %{"workflow_id" => _} = meta} | _] = jobs, opts) do
    {check, opts} = Keyword.pop(opts, :check_deps, true)

    workflow_opts =
      meta
      |> Map.take(~w(workflow_id workflow_name))
      |> Keyword.new(fn {key, val} -> {String.to_existing_atom(key), val} end)

    workflow =
      opts
      |> Keyword.merge(workflow_opts)
      |> new()

    %{workflow | check_deps: check, names: MapSet.new(jobs, & &1.meta["name"])}
  end

  def append(%Job{} = job, opts), do: append([job], opts)

  @doc """
  Generates a UUIDv7 based workflow id.

  ## Examples

      iex> Workflow.gen_id()
      "018e5d3b-1bb6-7f60-9c12-d6ed50cfff59"
  """
  @spec gen_id() :: String.t()
  def gen_id do
    Oban.Pro.UUIDv7.generate()
  end

  @doc """
  Converts the given workflow to DOT format, which can then be converted to a number of other
  formats via Graphviz, e.g. `dot -Tpng out.dot > out.png`.

  The default implementation relies on [libgraph](https://hexdocs.pm/libgraph/Graph.html).

  ## Examples

  Generate a DOT graph format from a workflow:

      Workflow.to_dot(workflow)
  """
  @spec to_dot(flow :: t()) :: String.t()
  def to_dot(%__MODULE__{changesets: changesets}) do
    {:ok, dot} =
      changesets
      |> Enum.map(&{&1.changes.meta.name, &1.changes.worker, &1.changes.meta.deps})
      |> Enum.reduce(Graph.new(), fn {name, worker, deps}, graph ->
        label = "#{name} (#{worker})"

        graph
        |> Graph.add_vertex(name, label)
        |> Graph.add_edges(for dep <- deps, do: {dep, name})
      end)
      |> Graph.to_dot()

    dot
  end

  @doc """
  Get all jobs for a workflow, optionally filtered by upstream deps.

  ## Examples

  Retrieve all workflow jobs:

      @impl Workflow
      def process(%Job{} = job) do
        job
        |> Workflow.all_jobs()
        |> do_things_with_jobs()

        :ok
      end

  Retrieve only the current job's deps:

      workflow_jobs = Workflow.all_jobs(job, only_deps: true)

  Retrieve an explicit list of dependencies:

      [job_a, job_b] = Workflow.all_jobs(job, names: [:a, :b])
  """
  @spec all_jobs(Job.t(), [fetch_option()]) :: [Job.t()]
  def all_jobs(
        %Job{conf: conf, meta: %{"deps" => deps, "workflow_id" => workflow_id}},
        opts \\ []
      ) do
    {query_opts, opts} = Keyword.split(opts, [:names, :only_deps])

    Repo.all(conf, workflow_query(workflow_id, deps, query_opts), opts)
  end

  @doc """
  Stream all jobs for a workflow.

  ## Examples

  Stream with filtering to only preserve `completed` jobs:

    @impl true
    def process(%Job{} = job) do
      {:ok, workflow_jobs} =
        MyApp.Repo.transaction(fn ->
          job
          |> Workflow.stream_jobs()
          |> Stream.filter(& &1.state == "completed")
          |> Enum.to_list()
        end)

      do_things_with_jobs(workflow_jobs)

      :ok
    end
  """
  @spec stream_jobs(Job.t(), [fetch_option()]) :: Enum.t()
  def stream_jobs(%Job{conf: conf, meta: %{"deps" => deps, "workflow_id" => workflow_id}}, opts) do
    {query_opts, opts} = Keyword.split(opts, [:names, :only_deps])

    Repo.stream(conf, workflow_query(workflow_id, deps, query_opts), opts)
  end

  # Helpers

  defp prevent_dupe!(workflow, name) do
    if MapSet.member?(workflow.names, name) do
      raise "#{inspect(name)} is already a member of the workflow"
    end
  end

  defp ensure_workflow!(name, changeset) do
    with {:ok, worker} <- Changeset.fetch_change(changeset, :worker),
         {:ok, worker} <- Worker.from_string(worker) do
      unless function_exported?(worker, :new_workflow, 1) do
        raise "#{inspect(name)} does not implement the Workflow behaviour"
      end
    end
  end

  defp confirm_deps!(_workflow, []), do: :ok

  defp confirm_deps!(workflow, deps) do
    missing = for name <- deps, not MapSet.member?(workflow.names, name), do: name

    unless Enum.empty?(missing) do
      raise "deps #{inspect(missing)} are not members of the workflow"
    end
  end

  # Query Helpers

  defp workflow_query(workflow_id, deps, opts) do
    Job
    |> where([j], fragment("? @> ?", j.meta, ^%{workflow_id: workflow_id}))
    |> order_by(asc: :id)
    |> scope_to_deps(deps, opts)
  end

  defp scope_to_deps(query, deps, opts) do
    cond do
      is_list(opts[:names]) ->
        names = Enum.map(opts[:names], &to_string/1)

        where(query, [j], j.meta["name"] in ^names)

      opts[:only_deps] ->
        where(query, [j], j.meta["name"] in ^deps)

      true ->
        query
    end
  end
end
