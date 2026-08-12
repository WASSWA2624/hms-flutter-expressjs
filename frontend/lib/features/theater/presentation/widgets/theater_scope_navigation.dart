import 'package:hosspi_hms/features/theater/domain/entities/theater_entities.dart';
import 'package:hosspi_hms/shared/components/components.dart';

export 'package:hosspi_hms/features/theater/domain/entities/theater_entities.dart'
    show
        theaterCaseMatchesRecoveryScope,
        theaterIsRecoveryStageFilter,
        theaterRecoveryStageFilter,
        theaterSectionTabCount;

AppTabCountTone theaterSectionCountTone(TheaterSection section) {
  return switch (section) {
    TheaterSection.scheduled ||
    TheaterSection.inTheater ||
    TheaterSection.recovery => AppTabCountTone.warning,
    TheaterSection.all || TheaterSection.followUps => AppTabCountTone.info,
  };
}
