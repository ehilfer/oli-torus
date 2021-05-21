import { createAsyncThunk } from '@reduxjs/toolkit';
import { writePageAttemptState } from 'data/persistence/state/intrinsic';
import { RootState } from '../../../rootReducer';
import { loadActivities, loadActivityState } from '../../groups/actions/deck';
import { selectSequence } from '../../groups/selectors/deck';
import { LayoutType, selectCurrentGroup, setGroups } from '../../groups/slice';
import { loadPageState, PageSlice, PageState, selectResourceAttemptGuid } from '../slice';

export const loadInitialPageState = createAsyncThunk(
  `${PageSlice}/loadInitialPageState`,
  async (params: PageState, thunkApi) => {
    const { dispatch, getState } = thunkApi;

    await dispatch(loadPageState(params));

    const groups = params.content.model.filter((item: any) => item.type === 'group');
    const otherTypes = params.content.model.filter((item: any) => item.type !== 'group');
    // for now just stick them into a group, this isn't reallly thought out yet
    // and there is technically only 1 supported layout type atm
    if (otherTypes.length) {
      groups.push({ type: 'group', layout: 'deck', children: [...otherTypes] });
    }
    // wait for this to resolve so that state will be updated
    await dispatch(setGroups({ groups }));

    const currentGroup = selectCurrentGroup(getState() as RootState);
    if (currentGroup?.layout === LayoutType.DECK) {
      // write initial session state (TODO: factor out elsewhere)
      const resourceAttemptGuid = selectResourceAttemptGuid(getState() as RootState);
      const sequence = selectSequence(getState() as RootState);
      const sessionState = sequence.reduce((acc, entry) => {
        acc[`session.visits.${entry.custom.sequenceId}`] = 0;
        return acc;
      }, {});
      await writePageAttemptState(
        params.sectionSlug,
        resourceAttemptGuid,
        sessionState,
        params.previewMode,
      );
      if (params.previewMode) {
        // need to load activities from the authoring api
        const activityIds = currentGroup.children.map((child: any) => child.activity_id);
        dispatch(loadActivities(activityIds));
      } else {
        // need to load activities from the delivery (attempt) api
        const attemptGuids = Object.keys(params.activityGuidMapping).map((activityResourceId) => {
          const { attemptGuid } = params.activityGuidMapping[activityResourceId];
          return attemptGuid;
        });
        dispatch(loadActivityState(attemptGuids));
      }
    }
  },
);