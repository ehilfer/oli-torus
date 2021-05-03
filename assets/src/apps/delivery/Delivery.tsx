import useWindowSize from 'components/hooks/useWindowSize';
import React, { useEffect } from 'react';
import { Provider } from 'react-redux';
import AdaptivePageView from './formats/adaptive/AdaptivePageView';
import store from './store';
import { loadActivities, loadActivityState } from './store/features/activities/slice';
import { loadPageState } from './store/features/page/slice';

export interface DeliveryProps {
  resourceId: number;
  sectionSlug: string;
  userId: number;
  pageSlug: string;
  content: any;
  resourceAttemptState: any;
  resourceAttemptGuid: string;
  activityGuidMapping: any;
}

export const Delivery: React.FunctionComponent<DeliveryProps> = (props: DeliveryProps) => {
  useEffect(() => {
    const {
      userId,
      resourceId,
      sectionSlug,
      pageSlug,
      content,
      resourceAttemptGuid,
      resourceAttemptState,
      activityGuidMapping,
    } = props;

    store.dispatch(
      loadPageState({
        userId,
        resourceId,
        sectionSlug,
        pageSlug,
        content,
        resourceAttemptGuid,
        resourceAttemptState,
        activityGuidMapping,
      }),
    );

    // for the moment load *all* the activity state
    const attemptGuids = Object.keys(activityGuidMapping).map((activityResourceId) => {
      const { attemptGuid } = activityGuidMapping[activityResourceId];
      return attemptGuid;
    });
    store.dispatch(loadActivityState(attemptGuids));
  }, []);

  const parentDivClasses: string[] = [];
  if (props.content?.custom?.viewerSkin) {
    parentDivClasses.push(`skin-${props.content?.custom?.viewerSkin}`);
  }

  // this is something SS does...
  const { width: windowWidth } = useWindowSize();

  return (
    <Provider store={store}>
      <div className={parentDivClasses.join(' ')}>
        <div className="mainView" role="main" style={{ width: windowWidth }}>
          <AdaptivePageView />
        </div>
      </div>
    </Provider>
  );
};