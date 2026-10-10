# Trainz development roadmap

This roadmap combines the earlier gameplay suggestions with the requested future
features. The phases are a proposed development order, not release dates. Features
listed as planned are not implemented yet. Keep the core game playable while adding
each system, with Godot and GDScript as the main development tools.

## Current foundation

- Mouse-drawn tracks with automatic bends, diagonals and a straight first extension
  tile when departing existing rails.
- Construction costs, drag demolition and paused construction Undo/Redo.
- Passenger and log-freight services, production and delivery income.
- Separate speed and capacity upgrades.
- Named services and ordered passenger stops across Stations A, B and C.
- Station inspection, camera scrolling, minimap, introductory objectives and saves.

These are prototype foundations. Named services do not yet include a purchasable
fleet, individual passenger destinations, junction dispatching or shared-track safety.

## Phase 1 — Routing, fleet control and readable feedback

| Planned feature | Intended gameplay or visual benefit | Dependencies and scope |
| --- | --- | --- |
| Train purchasing and route assignment | Buy additional trains and allocate capacity where demand is highest. Retain separate speed and capacity purchases. | Build a fleet model with persistent train identities; enable multiple trains on a shared track only once reservations and signals are ready. |
| Junctions and switches | Build branching networks and share infrastructure between services. | Extend track connections and route selection beyond two-port pieces. |
| Block signals and track reservations | Prevent collisions and introduce dispatching decisions. | Support safe waiting, junction conflicts and recovery from blocked routes. |
| Waypoints and waypoint directives | Place lightweight markers or directional waypoints to force a train through a particular track without constructing a station. Allow routing directives associated with signals. | Extend ordered routes with pass-through instructions and direction constraints. Keep routing directives distinct from a signal's safety role: a directive must never override an occupied or reserved block. |
| Passing loops and multiple platforms | Reduce bottlenecks and let faster services pass slower trains. | Depends on junctions, reservations and platform assignment. |
| Route performance panel | Compare income, running costs, occupancy, waiting passengers and delays. | Attribute costs and deliveries to services and individual trains. |
| Custom livery and individual train naming | Rename locomotives and select fleet colour palettes. | Use stable train identities and palette-friendly artwork; preserve readable service indicators. Service names already exist, individual train names do not. |
| Detailed station life and waiting passengers | Show tiny pixel-art passengers accumulating on platforms during delays and boarding when trains arrive. | Drive visuals from actual queues; cap or group sprites for performance without changing simulated passenger counts. |

## Phase 2 — Passenger demand, freight chains and growth

| Planned feature | Intended gameplay or visual benefit | Dependencies and scope |
| --- | --- | --- |
| Passenger destinations and transfers | Reward networks that connect useful places, including journeys requiring a change of train. | Replace the current next-stop passenger model with origins, destinations and journey planning. |
| Express versus local passenger demand | High-paying express passengers prefer direct travel between distant hubs; commuters accept frequent stops along a local line. | Define clear rules for directness, stops, journey time and fares. Depends on passenger destinations and service performance data. |
| Industry supply chains | Move logs to sawmills, timber to factories, and finished goods to terminals. | Add cargo types, production recipes, storage limits and compatible loading rules. |
| Delivery contracts | Earn rewards for specified quantities delivered within deadlines. | Extend the existing objective system with selectable, timed contracts and clear failure conditions. |
| Town and industry growth | Let reliable transport increase demand and create expansion opportunities. | Growth should respond to delivered service and connect to land ownership rules when introduced. |
| Sandbox and scenario modes | Offer relaxed construction alongside structured challenges. | Build on introductory objectives; expose economy, progression and difficulty settings. |

## Phase 3 — Infrastructure, maintenance and business decisions

| Planned feature | Intended gameplay or visual benefit | Dependencies and scope |
| --- | --- | --- |
| Terrain, bridges and tunnels | Balance construction cost against distance, grades and journey time. | Introduce terrain and elevation constraints before grade-dependent traction or weather effects. |
| Maintenance yards and breakdowns | Route trains to depots or maintenance sheds. Neglected trains become slower, cost more to run, or break down and block single-track sections. | Add condition, maintenance schedules, depot visits and repair/recovery actions. Depends on fleet identities and safe traffic reservations. Provide warnings and configurable difficulty. |
| Loans and debt | Borrow to fund expensive infrastructure such as tunnels, with variable interest and repayment obligations. | Show interest terms, rate changes, repayments and projected cash flow clearly. Define insolvency rules and sandbox alternatives. |
| Land purchase and transit rights | Buy land or access rights before town growth makes expansion more expensive. | Integrate ownership with construction previews, town growth and infrastructure costs. |
| Competitor AI and rivals | Rival railways claim territory or bid for limited industry rights. | Build on land rights, contracts and a stable economy. Start with bidding and territory competition before attempting fully autonomous railway construction. |

## Phase 4 — Historical progression and the changing environment

| Planned feature | Intended gameplay or visual benefit | Dependencies and scope |
| --- | --- | --- |
| Steam → diesel → electric eras | Advance through time or research investment. Early steam locomotives are affordable but slow; later electric trains offer high performance with costly electrification. | Add locomotive technology, operating costs, unlock rules and overhead catenary infrastructure. Validate that electric services have suitable electrified routes. Make era progression configurable for sandbox play. |
| Dynamic weather and seasons | Add rain, snow and autumn foliage. Snow can slow mountain passes or increase running costs; rain can reduce traction on steep inclines. | Separate visual effects from optional simulation penalties. Terrain grades and traction must exist before grade-based effects. Forecasts and clear status messages should explain operational changes. |

## Phase 5 — Building tools, spectators and community content

| Planned feature | Intended gameplay or visual benefit | Dependencies and scope |
| --- | --- | --- |
| Blueprints and copy/paste track designs | Save and reuse junctions, loops and terminal layouts. | Stabilise junction, signal and platform data first. Preview the full cost, land requirements and conflicts before placing a blueprint; support Undo for the whole placement. |
| Track-side spectator and ride-along camera | Follow a chosen train or watch a station at close zoom with minimal UI. | Use stable train targets, easy return to normal controls, and prevent accidental construction while watching. This can be implemented earlier than other Phase 5 features. |
| Level and scenario editor | Create maps, place industries and define delivery challenges for sharing. | Define a versioned content format, validate maps and objectives, and separate scenario definitions from saved sessions. Start with local import/export and sharing through community forums. Steam Workshop integration is a later distribution-specific option, not a requirement for using the editor. |

## Suggested next implementation

Introduce the fleet data model and train assignment UI, then junctions and block
reservations before allowing multiple trains to share a line. Extend ordered routes
with waypoint directives once alternate safe paths are available. Visual passenger
queues, liveries and spectator controls can be developed independently of most of
the deeper economy systems.
