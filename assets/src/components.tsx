import * as React from 'react';
import * as ReactDOM from 'react-dom';
import { Provider } from 'react-redux';
import { Maybe, maybe } from 'tsmonad';
import { Editor } from 'components/editing/editor/Editor';
import { configureStore } from 'state/store';
import { TestEditor } from 'components/editing/EditorTest';
import { ResourceEditor } from 'components/resource/resourceEditor/ResourceEditor';
import { ActivityEditor } from 'components/activity/ActivityEditor';

export const registry = {
  Editor,
  TestEditor,
  ResourceEditor,
  ActivityEditor,
} as any;

export type ComponentName = keyof typeof registry;

let store = configureStore();

// Expose React/Redux APIs to server-side rendered templates
(window as any).component = {
  mount: (componentName: ComponentName, element: HTMLElement, context: any = {}) => {
    maybe(registry[componentName]).lift((Component) => {
      ReactDOM.render(
        <Provider store={store}>
          <Component {...context} />
        </Provider>,
        element,
      );
    });
  },
};

(window as any).store = {
  configureStore: (json: any) => {
    store = configureStore(json);
  },
};

// Expose other libraries to server-side rendered templates
(window as any).Maybe = Maybe;