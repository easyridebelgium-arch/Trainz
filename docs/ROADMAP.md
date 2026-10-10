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
| Train consists and rolling stock | Assemble locomotives with passenger coaches of different classes, boxcars, tankers, hoppers and flatcars. Give each vehicle its own capacity, loading speed and cargo suitability. | Extend the fleet model with vehicle composition, cargo compatibility and total train length. Account for platform and block lengths before running long consists. Introduce stock types as their passenger classes or cargo types become available. |
| Junctions and switches | Build branching networks and share infrastructure between services. | Extend track connections and route selection beyond two-port pieces. |
| Block signals and track reservations | Prevent collisions and introduce dispatching decisions. | Support safe waiting, junction conflicts and recovery from blocked routes. |
| Priority and pathfinding rules | Offer simple dispatch priorities, initially express > local passenger > freight, so players can influence junction behaviour without configuring complex signalling. | Priorities choose between safe movements; they never override reservations. Allow player overrides, explain why a train is waiting, and prevent low-priority services from waiting indefinitely. Respect waypoint directives when choosing paths. |
| Waypoints and waypoint directives | Place lightweight markers or directional waypoints to force a train through a particular track without constructing a station. Allow routing directives associated with signals. | Extend ordered routes with pass-through instructions and direction constraints. Keep routing directives distinct from a signal's safety role: a directive must never override an occupied or reserved block. |
| Passing loops and multiple platforms | Reduce bottlenecks and let faster services pass slower trains. | Depends on junctions, reservations and platform assignment. |
| Route performance panel and company dashboard | Compare income, running costs, occupancy, waiting passengers and delays. Expand into historical graphs of profit, ridership, occupancy and punctuality per route and across the company. | Attribute costs and deliveries to services and individual trains. Start recording bounded historical data early; add delay statistics when timetables are introduced. |
| Custom livery and individual train naming | Rename locomotives and select fleet colour palettes. | Use stable train identities and palette-friendly artwork; preserve readable service indicators. Service names already exist, individual train names do not. |
| Detailed station life and waiting passengers | Show tiny pixel-art passengers accumulating on platforms during delays and boarding when trains arrive. | Drive visuals from actual queues; cap or group sprites for performance without changing simulated passenger counts. |

## Phase 2 — Passenger demand, freight chains and growth

| Planned feature | Intended gameplay or visual benefit | Dependencies and scope |
| --- | --- | --- |
| Passenger destinations and transfers | Reward networks that connect useful places, including journeys requiring a change of train. | Replace the current next-stop passenger model with origins, destinations and journey planning. |
| Express versus local passenger demand | High-paying express passengers prefer direct travel between distant hubs; commuters accept frequent stops along a local line. | Define clear rules for directness, stops, journey time and fares. Depends on passenger destinations and service performance data. |
| Timetables and service frequencies | Set exact departures or recurring frequencies. Early and late arrivals affect passenger satisfaction and freight contract payouts. | Build on a simulation clock, station dwell rules and shared-track dispatching. Define tolerances, holding for scheduled departure, missed services and recovery from delays; show the consequences before players accept a contract. |
| Industry supply chains | Move logs to sawmills, timber to factories, and finished goods to terminals. | Add cargo types, production recipes, storage limits and compatible loading rules. |
| Cargo with distinct behaviours | Perishable cargo spoils over time, hazardous materials need lower speeds or special handling, and high-value express cargo rewards fast delivery. | Track shipment age and delivery terms; connect cargo requirements to rolling stock, facilities and routing. Make spoilage, restrictions and bonuses visible before loading. |
| Station facilities and amenities | Add platforms, waiting rooms, cargo warehouses and fuel depots to increase capacity, shorten loading times or lower running costs. | Extend station construction and upgrades with clear benefits and costs. Tie platform capacity to train length, warehouses to cargo storage, and fuel facilities to compatible locomotive technology. |
| Delivery contracts | Earn rewards for specified quantities delivered within deadlines. | Extend the existing objective system with selectable, timed contracts and clear failure conditions. |
| Company reputation and passenger satisfaction | Reward reliable, comfortable service with demand growth, better contracts and subsidies instead of rewarding only transport volume. | Use understandable measures such as punctuality, crowding, journey time and amenities. Show causes and recovery options; connect reputation to town growth and contract availability. |
| Town and industry growth | Let reliable transport increase demand and create expansion opportunities. | Growth should respond to delivered service and connect to land ownership rules when introduced. |
| Sandbox and scenario modes | Offer relaxed construction alongside structured challenges. | Build on introductory objectives; expose economy, progression and difficulty settings. |

## Phase 3 — Infrastructure, maintenance and business decisions

| Planned feature | Intended gameplay or visual benefit | Dependencies and scope |
| --- | --- | --- |
| Terrain, bridges and tunnels | Balance construction cost against distance, grades and journey time. | Introduce terrain and elevation constraints before grade-dependent traction or weather effects. |
| Maintenance yards and breakdowns | Route trains to depots or maintenance sheds. Neglected trains become slower, cost more to run, or break down and block single-track sections. | Add condition, maintenance schedules, depot visits and repair/recovery actions. Depends on fleet identities and safe traffic reservations. Provide warnings and configurable difficulty. |
| Depots and stabling tracks | Store spare trains, hold vehicles between services and provide cleaning facilities away from running lines. | Share depot access and fleet management with maintenance yards. Track siding capacity and safe entry/exit reservations; add timetable-based layovers when schedules exist. Parking and cleaning remain distinct from mechanical maintenance. |
| Loans and debt | Borrow to fund expensive infrastructure such as tunnels, with variable interest and repayment obligations. | Show interest terms, rate changes, repayments and projected cash flow clearly. Define insolvency rules and sandbox alternatives. |
| Land purchase and transit rights | Buy land or access rights before town growth makes expansion more expensive. | Integrate ownership with construction previews, town growth and infrastructure costs. |
| Competitor AI and rivals | Rival railways claim territory or bid for limited industry rights. | Build on land rights, contracts and a stable economy. Start with bidding and territory competition before attempting fully autonomous railway construction. |

## Phase 4 — Historical progression and the changing environment

| Planned feature | Intended gameplay or visual benefit | Dependencies and scope |
| --- | --- | --- |
| Steam → diesel → electric eras | Advance through time or research investment. Early steam locomotives are affordable but slow; later electric trains offer high performance with costly electrification. | Add locomotive technology, operating costs, unlock rules and overhead catenary infrastructure. Validate that electric services have suitable electrified routes. Make era progression configurable for sandbox play. |
| Research and technology tree | Invest in better signalling, higher-speed track, efficient locomotives and advanced cargo handling for long-term goals. | Use one unlock system shared with historical eras rather than separate conflicting progressions. Show prerequisites, research costs and benefits, with configurable time-based or investment-based progression. |
| Dynamic weather and seasons | Add rain, snow and autumn foliage. Snow can slow mountain passes or increase running costs; rain can reduce traction on steep inclines. | Separate visual effects from optional simulation penalties. Terrain grades and traction must exist before grade-based effects. Forecasts and clear status messages should explain operational changes. |
| Dynamic events and disruptions | Introduce temporary closures, sudden demand surges and other challenges that prompt network adjustments during sandbox play. | Reuse demand, contracts, weather and maintenance systems where appropriate. Give events clear duration, advance information when appropriate, recovery conditions and configurable frequency. |

## Phase 5 — Building tools, spectators and community content

| Planned feature | Intended gameplay or visual benefit | Dependencies and scope |
| --- | --- | --- |
| Blueprints and copy/paste track designs | Save and reuse junctions, loops and terminal layouts. | Stabilise junction, signal and platform data first. Preview the full cost, land requirements and conflicts before placing a blueprint; support Undo for the whole placement. |
| Camera tools, spectator views and traffic overview | Expand existing camera scrolling and the minimap with free-camera controls, train-follow/ride-along mode, close station views with minimal UI, and a network traffic-density heat map. | Use stable train targets and traffic measurements, an easy return to normal controls, and protection against accidental construction while watching. Spectator controls can arrive earlier; the heat map builds on dashboard data. |
| Photo mode and sharing tools | Capture screenshots with optional route-name and train-information overlays for sharing. | Build on camera tools and selectable UI visibility. Start with local image export; keep posting to external services a deliberate player action. |
| Railway sound design | Give locomotives distinct horns and rail sounds, add station announcements, and use ambient audio to make the network feel alive. | Tie sounds to train type, speed, distance and station events. Provide separate volume controls and visual equivalents for important audio cues; use appropriately licensed or original assets. |
| Level and scenario editor | Create maps, place industries and define delivery challenges for sharing. | Define a versioned content format, validate maps and objectives, and separate scenario definitions from saved sessions. Start with local import/export and sharing through community forums. Steam Workshop integration is a later distribution-specific option, not a requirement for using the editor. |
| Lightweight modding | Support custom scenarios, train sprites and simple cargo definitions to extend the game and encourage community contributions. | Reuse scenario formats and data-driven vehicle/cargo definitions. Document schemas, asset requirements and version compatibility; validate content and report missing assets clearly. Start with data and asset packs rather than requiring executable mods. |

## Modes, learning and accessibility — across all phases

| Planned feature | Intended gameplay benefit | Dependencies and scope |
| --- | --- | --- |
| Tutorial campaigns with progressive unlocking | Teach track building → stations → signals → contracts → growth, one system at a time. | Expand introductory objectives into guided scenarios as each system becomes available. Provide contextual explanations, repeatable lessons and an option to skip tutorials. |
| Difficulty modifiers | Offer higher running costs, stricter contracts, optional no-pause play, and adjustable maintenance, weather and event pressure. | Present modifiers explicitly when creating a game and save them with the scenario. Keep a relaxed sandbox preset; ensure no-pause play still offers a usable route-editing workflow instead of relying on the current automatic pause. |
| Achievements and challenge packs | Add replayable goals such as delivering a passenger target without delays or connecting every town below a track-length budget. | Extend scenario objectives with measurable constraints and clear eligibility rules for difficulty settings. Support local progress first; platform achievements are optional integration work. |

## Suggested next implementation

Introduce the fleet data model and train assignment UI with room for vehicle
consists, then junctions and block reservations before allowing multiple trains to
share a line. Extend ordered routes with waypoint directives and dispatch priorities
once alternate safe paths are available. Timetables then connect operations to
passenger satisfaction and contract performance. Visual passenger queues, liveries,
sound and spectator controls can develop alongside these systems. Add tutorial
steps and difficulty controls as each gameplay system arrives rather than leaving
all teaching and accessibility work until the end.
