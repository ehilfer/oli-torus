import { JSONSchema7 } from 'json-schema';
import { debounce, isEqual } from 'lodash';
import Delta from 'quill-delta';
import React, { useCallback, useEffect, useState } from 'react';
import { Button, ButtonGroup, ButtonToolbar, Modal, Tab, Tabs } from 'react-bootstrap';
import ReactQuill from 'react-quill';
import { useDispatch, useSelector } from 'react-redux';
import { clone } from 'utils/common';
import {
  selectRightPanelActiveTab,
  setRightPanelActiveTab,
} from '../../../authoring/store/app/slice';
import { selectCurrentActivityTree } from '../../../delivery/store/features/groups/selectors/deck';
import { selectCurrentGroup } from '../../../delivery/store/features/groups/slice';
import { saveActivity } from '../../store/activities/actions/saveActivity';
import { updateSequenceItemFromActivity } from '../../store/groups/layouts/deck/actions/updateSequenceItemFromActivity';
import { savePage } from '../../store/page/actions/savePage';
import { selectState as selectPageState, updatePage } from '../../store/page/slice';
import { selectCurrentSelection, setCurrentSelection } from '../../store/parts/slice';
import { convertJanusToQuill, convertQuillToJanus } from '../EditingCanvas/TextFlowHelpers';
import AccordionTemplate from '../PropertyEditor/custom/AccordionTemplate';
import ColorPickerWidget from '../PropertyEditor/custom/ColorPickerWidget';
import CustomFieldTemplate from '../PropertyEditor/custom/CustomFieldTemplate';
import PropertyEditor from '../PropertyEditor/PropertyEditor';
import lessonSchema, {
  lessonUiSchema,
  transformModelToSchema as transformLessonModel,
  transformSchemaToModel as transformLessonSchema,
} from '../PropertyEditor/schemas/lesson';
import partSchema, {
  partUiSchema,
  transformModelToSchema as transformPartModelToSchema,
  transformSchemaToModel as transformPartSchemaToModel,
} from '../PropertyEditor/schemas/part';
import screenSchema, {
  screenUiSchema,
  transformScreenModeltoSchema,
  transformScreenSchematoModel,
} from '../PropertyEditor/schemas/screen';

export enum RightPanelTabs {
  LESSON = 'lesson',
  SCREEN = 'screen',
  COMPONENT = 'component',
}

const RightMenu: React.FC<any> = () => {
  const dispatch = useDispatch();
  const selectedTab = useSelector(selectRightPanelActiveTab);
  const currentActivityTree = useSelector(selectCurrentActivityTree);
  const currentLesson = useSelector(selectPageState);
  const currentGroup = useSelector(selectCurrentGroup);
  const currentPartSelection = useSelector(selectCurrentSelection);

  // TODO: dynamically load schema from Part Component configuration
  const [componentSchema, setComponentSchema]: any = useState<any>(partSchema);
  const [componentUiSchema, setComponentUiSchema]: any = useState<any>(partUiSchema);
  const [currentComponent, setCurrentComponent] = useState<any>(null);

  const [currentActivity] = (currentActivityTree || []).slice(-1);

  const [screenData, setScreenData] = useState();
  useEffect(() => {
    if (!currentActivity) {
      return;
    }
    console.log('CURRENT', { currentActivity, currentLesson });
    setScreenData(transformScreenModeltoSchema(currentActivity));
  }, [currentActivity]);

  // should probably wrap this in state too, but it doesn't change really
  const lessonData = transformLessonModel(currentLesson);

  const handleSelectTab = (key: RightPanelTabs) => {
    // TODO: any other saving or whatever
    dispatch(setRightPanelActiveTab({ rightPanelActiveTab: key }));
  };

  const screenPropertyChangeHandler = useCallback(
    (properties: any) => {
      if (currentActivity) {
        const modelChanges = transformScreenSchematoModel(properties);
        console.log('Screen Property Change...', { properties, modelChanges });
        const title = modelChanges.title;
        delete modelChanges.title;
        const screenChanges = {
          ...currentActivity?.content?.custom,
          ...modelChanges,
        };
        const cloneActivity = clone(currentActivity);
        cloneActivity.content.custom = screenChanges;
        if (title) {
          cloneActivity.title = title;
        }
        debounceSaveScreenSettings(cloneActivity, currentActivity, currentGroup);
      }
    },
    [currentActivity],
  );

  const debounceSaveScreenSettings = useCallback(
    debounce(
      (activity, currentActivity, group) => {
        console.log('SAVING ACTIVITY:', { activity });
        dispatch(saveActivity({ activity }));

        if (activity.title !== currentActivity?.title) {
          dispatch(updateSequenceItemFromActivity({ activity: activity, group: group }));
          dispatch(savePage());
        }
      },
      500,
      { maxWait: 10000, leading: false },
    ),
    [],
  );

  const debounceSavePage = useCallback(
    debounce(
      (changes) => {
        console.log('SAVING PAGE', { changes });
        // update server
        dispatch(savePage(changes));
        // update redux
        // TODO: check if revision slug changes?
        dispatch(updatePage(changes));
      },
      500,
      { maxWait: 10000, leading: false },
    ),
    [],
  );

  const lessonPropertyChangeHandler = (properties: any) => {
    const modelChanges = transformLessonSchema(properties);

    // special consideration for legacy stylesheets
    if (modelChanges.additionalStylesheets[0] === null) {
      modelChanges.additionalStylesheets[0] = (currentLesson.additionalStylesheets || [])[0];
    }

    const lessonChanges = {
      ...currentLesson,
      ...modelChanges,
      custom: { ...currentLesson.custom, ...modelChanges.custom },
    };
    //need to remove the allowNavigation property
    //making sure the enableHistory is present before removing that.
    if (
      lessonChanges.custom.enableHistory !== undefined &&
      lessonChanges.custom.allowNavigation !== undefined
    ) {
      delete lessonChanges.custom.allowNavigation;
    }
    console.log('LESSON PROP CHANGED', { modelChanges, lessonChanges, properties });

    // need to put a healthy debounce in here, this fires every keystroke
    // save the page
    debounceSavePage(lessonChanges);
  };

  const debouncePartPropertyChanges = useCallback(
    debounce(
      (properties, partInstance, origActivity, origId) => {
        let modelChanges = properties;
        if (partInstance && partInstance.transformSchemaToModel) {
          modelChanges.custom = partInstance.transformSchemaToModel(properties.custom);
        }
        modelChanges = transformPartSchemaToModel(modelChanges);
        console.log('COMPONENT PROP CHANGED', { properties, modelChanges });

        const cloneActivity = clone(origActivity);
        const ogPart = cloneActivity.content?.partsLayout.find((part: any) => part.id === origId);
        if (!ogPart) {
          // hopefully UI will prevent this from happening
          console.warn(
            'couldnt find part in current activity, most like lives on a layer; you need to update they layer copy directly',
          );
          return;
        }
        if (modelChanges.id !== ogPart.id) {
          ogPart.id = modelChanges.id;
          // also need to update the authoring.parts
          const authoringPart = cloneActivity.authoring?.parts?.find(
            (p: any) => p.id === ogPart.id,
          );
          // TODO: if that isn't found, then it's a problem. maybe should write it new?
          if (authoringPart) {
            authoringPart.id = modelChanges.id;
          }
          // in case the id changes, update the selection
          dispatch(setCurrentSelection({ selection: modelChanges.id }));
        }
        ogPart.custom = modelChanges.custom;

        if (!isEqual(cloneActivity, origActivity)) {
          dispatch(saveActivity({ activity: cloneActivity }));
        }
      },
      500,
      { maxWait: 10000, leading: false },
    ),
    [],
  );

  const [currentComponentData, setCurrentComponentData] = useState<any>(null);
  const [currentPartInstance, setCurrentPartInstance] = useState<any>(null);
  useEffect(() => {
    if (!currentPartSelection || !currentActivityTree) {
      return;
    }
    let partDef;
    for (let i = 0; i < currentActivityTree.length; i++) {
      const activity = currentActivityTree[i];
      partDef = activity.content?.partsLayout.find((part: any) => part.id === currentPartSelection);
      if (partDef) {
        break;
      }
    }
    console.log('part selected', { partDef });
    if (partDef) {
      // part component should be registered by type as a custom element
      const PartClass = customElements.get(partDef.type);
      if (PartClass) {
        const instance = new PartClass();

        setCurrentPartInstance(instance);

        let data = clone(partDef);
        if (instance.transformModelToSchema) {
          // because the part schema below only knows about the "custom" block
          data.custom = instance.transformModelToSchema(partDef.custom);
        }
        data = transformPartModelToSchema(data);
        setCurrentComponentData(data);

        // schema
        if (instance.getSchema) {
          const customPartSchema = instance.getSchema();
          const newSchema: any = {
            ...partSchema,
            properties: {
              ...partSchema.properties,
              custom: { type: 'object', properties: { ...customPartSchema } },
            },
          };
          if (customPartSchema.definitions) {
            newSchema.definitions = customPartSchema.definitions;
            delete newSchema.properties.custom.properties.definitions;
          }
          setComponentSchema(newSchema);
        }

        // ui schema
        if (instance.getUiSchema) {
          const customPartUiSchema = instance.getUiSchema();
          const newUiSchema = {
            ...partUiSchema,
            custom: {
              'ui:ObjectFieldTemplate': AccordionTemplate,
              'ui:title': 'Custom',
              ...customPartUiSchema,
            },
          };
          const customPartSchema = instance.getSchema();
          if (customPartSchema.palette) {
            newUiSchema.custom = {
              ...newUiSchema.custom,
              palette: {
                'ui:ObjectFieldTemplate': CustomFieldTemplate,
                'ui:title': 'Palette',
                backgroundColor: {
                  'ui:widget': ColorPickerWidget,
                },
                borderColor: {
                  'ui:widget': ColorPickerWidget,
                },
                borderStyle: { classNames: 'col-6' },
                borderWidth: { classNames: 'col-6' },
              },
            };
          }
          setComponentUiSchema(newUiSchema);
        }
      }
      setCurrentComponent(partDef);
    }
    return () => {
      setComponentSchema(partSchema);
      setComponentUiSchema(partUiSchema);
      setCurrentComponent(null);
      setCurrentComponentData(null);
      setCurrentPartInstance(null);
    };
  }, [currentPartSelection, currentActivityTree]);

  const componentPropertyChangeHandler = useCallback(
    (properties: any) => {
      debouncePartPropertyChanges(
        properties,
        currentPartInstance,
        currentActivity,
        currentPartSelection,
      );
    },
    [currentActivity, currentPartInstance, currentPartSelection],
  );

  const handleDeleteComponent = useCallback(() => {
    // only allow delete of "owned" parts
    // TODO: disable/hide button if that is not owned
    if (!currentActivity || !currentPartSelection) {
      return;
    }
    const partDef = currentActivity.content?.partsLayout.find(
      (part: any) => part.id === currentPartSelection,
    );
    if (!partDef) {
      console.warn(`Part with id ${currentPartSelection} not found on this screen`);
      return;
    }
    const cloneActivity = clone(currentActivity);
    cloneActivity.authoring.parts = cloneActivity.authoring.parts.filter(
      (part: any) => part.id !== currentPartSelection,
    );
    cloneActivity.content.partsLayout = cloneActivity.content.partsLayout.filter(
      (part: any) => part.id !== currentPartSelection,
    );
    dispatch(saveActivity({ activity: cloneActivity }));
    dispatch(setCurrentSelection({ selection: '' }));
    dispatch(setRightPanelActiveTab({ rightPanelActiveTab: RightPanelTabs.SCREEN }));
  }, [currentPartSelection, currentActivity]);

  const [showTextModal, setShowTextModal] = useState(false);

  const [textDelta, setTextDelta] = useState<any>(null);
  const fakeValue = `<div id="a:98137:q:1535559999043:482:2" data-janus-type="janus-text-flow" class="" style="position: absolute; top: 190px; left: 330px; z-index: 2; overflow-wrap: break-word; line-height: inherit; width: 340px; border-width: 0.1px; border-style: solid; border-color: rgba(255, 255, 255, 0); background-color: rgba(255, 255, 255, 0);"><p style="direction:ltr; text-align:start; text-indent:0px; width:340px; display:block;"><span style="baseline-shift:0; color:rgb(51, 51, 51); dominant-baseline:auto; font-family:Arial; font-size:16px; font-style:normal; font-weight:normal; line-height:120%; text-decoration:none;">This lesson is inspired by actual events in western Europe during the Middle Ages and Renaissance Era. </span></p><p style="direction:ltr; text-align:start; text-indent:0px; width:340px; display:block;"><span style="baseline-shift:0; dominant-baseline:auto; font-family:Arial; font-size:16px; font-style:normal; font-weight:normal; line-height:120%; text-decoration:none;">&nbsp;</span></p><p style="direction:ltr; text-align:start; text-indent:0px; width:340px; display:block;"><span style="baseline-shift:0; dominant-baseline:auto; font-family:Arial; font-size:16px; font-style:normal; font-weight:normal; line-height:120%; text-decoration:none;">During this time, new inventions and discoveries changed the world nearly every day.</span></p><p style="direction:ltr; text-align:start; text-indent:0px; width:340px; display:block;"><span style="baseline-shift:0; dominant-baseline:auto; font-family:Arial; font-size:16px; font-style:normal; font-weight:normal; line-height:120%; text-decoration:none;">&nbsp;</span></p><p style="direction:ltr; text-align:start; text-indent:0px; width:340px; display:block;"><span style="baseline-shift:0; dominant-baseline:auto; font-family:Arial; font-size:16px; font-style:normal; font-weight:normal; line-height:120%; text-decoration:none;">We’ve included pictures and paintings of real people and key places to help you feel part of the time and place. As you learn about eclipses, take some time to imagine yourself as a part of this unique time in history.</span></p><p style="direction:ltr; text-align:start; text-indent:0px; width:340px; display:block;"><span style="baseline-shift:0; color:rgb(51, 51, 51); dominant-baseline:auto; font-family:Arial; font-size:16px; font-style:normal; font-weight:normal; line-height:120%; text-decoration:none;">&nbsp;</span></p></div>`;

  useEffect(() => {
    if (!currentComponentData) {
      return;
    }

    if (currentComponentData.type === 'janus-text-flow') {
      const delta = convertJanusToQuill(currentComponentData.custom.nodes);
      console.log('DELTA FORCE', delta);
      setTextDelta(delta);
    }
  }, [currentComponentData]);

  return (
    <Tabs
      className="aa-panel-section-title-bar aa-panel-tabs"
      activeKey={selectedTab}
      onSelect={handleSelectTab}
    >
      <Tab eventKey={RightPanelTabs.LESSON} title="Lesson">
        <div className="lesson-tab">
          <PropertyEditor
            schema={lessonSchema as JSONSchema7}
            uiSchema={lessonUiSchema}
            value={lessonData}
            onChangeHandler={lessonPropertyChangeHandler}
          />
        </div>
      </Tab>
      <Tab eventKey={RightPanelTabs.SCREEN} title="Screen">
        <div className="screen-tab p-3">
          {currentActivity && screenData ? (
            <PropertyEditor
              key={currentActivity.id}
              schema={screenSchema as JSONSchema7}
              uiSchema={screenUiSchema}
              value={screenData}
              onChangeHandler={screenPropertyChangeHandler}
            />
          ) : null}
        </div>
      </Tab>
      <Tab eventKey={RightPanelTabs.COMPONENT} title="Component" disabled={!currentComponent}>
        {currentComponent && currentComponentData && (
          <div className="component-tab p-3">
            <Modal
              show={showTextModal}
              onHide={() => setShowTextModal(false)}
              size="lg"
              aria-labelledby="contained-modal-title-vcenter"
              centered
            >
              <Modal.Header closeButton>
                <Modal.Title id="contained-modal-title-vcenter">Edit Text</Modal.Title>
              </Modal.Header>
              <Modal.Body>
                <ReactQuill
                  defaultValue={textDelta}
                  onChange={(content, delta, source, editor) => {
                    console.log('quill changes', { content, delta, source, editor });
                    const janusText = convertQuillToJanus(new Delta(editor.getContents().ops));
                    console.log('JANUS TEXT', janusText);
                  }}
                />
              </Modal.Body>
              <Modal.Footer>
                <Button onClick={() => setShowTextModal(false)}>Close</Button>
              </Modal.Footer>
            </Modal>
            <ButtonToolbar aria-label="Component Tools">
              <ButtonGroup className="me-2" aria-label="First group">
                <Button onClick={() => setShowTextModal(true)}>
                  <i className="fas fa-wrench mr-2" />
                </Button>
                <Button>
                  <i className="fas fa-cog mr-2" />
                </Button>
                <Button>
                  <i className="fas fa-copy mr-2" />
                </Button>
                <Button variant="danger" onClick={handleDeleteComponent}>
                  <i className="fas fa-trash mr-2" />
                </Button>
              </ButtonGroup>
            </ButtonToolbar>
            <PropertyEditor
              schema={componentSchema}
              uiSchema={componentUiSchema}
              value={currentComponentData}
              onChangeHandler={componentPropertyChangeHandler}
            />
          </div>
        )}
      </Tab>
    </Tabs>
  );
};
export default RightMenu;
