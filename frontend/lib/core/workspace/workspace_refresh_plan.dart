/// Declares which workspace data slices should be re-fetched over HTTP.
///
/// Used for targeted realtime refresh instead of reloading every visible list
/// after each event or mutation.
final class WorkspaceRefreshPlan {
  const WorkspaceRefreshPlan({
    this.appointments = false,
    this.queue = false,
    this.flows = false,
    this.triage = false,
    this.summaryCounts = false,
    this.selectedDetail = false,
    this.referenceData = false,
  });

  final bool appointments;
  final bool queue;
  final bool flows;
  final bool triage;
  final bool summaryCounts;
  final bool selectedDetail;
  final bool referenceData;

  static const WorkspaceRefreshPlan none = WorkspaceRefreshPlan();

  static const WorkspaceRefreshPlan full = WorkspaceRefreshPlan(
    appointments: true,
    queue: true,
    flows: true,
    triage: true,
    summaryCounts: true,
    selectedDetail: true,
    referenceData: true,
  );

  static const WorkspaceRefreshPlan flowWorkspace = WorkspaceRefreshPlan(
    flows: true,
    triage: true,
    summaryCounts: true,
    selectedDetail: true,
  );

  bool get isEmpty =>
      !appointments &&
      !queue &&
      !flows &&
      !triage &&
      !summaryCounts &&
      !selectedDetail &&
      !referenceData;

  WorkspaceRefreshPlan merge(WorkspaceRefreshPlan other) {
    return WorkspaceRefreshPlan(
      appointments: appointments || other.appointments,
      queue: queue || other.queue,
      flows: flows || other.flows,
      triage: triage || other.triage,
      summaryCounts: summaryCounts || other.summaryCounts,
      selectedDetail: selectedDetail || other.selectedDetail,
      referenceData: referenceData || other.referenceData,
    );
  }
}
