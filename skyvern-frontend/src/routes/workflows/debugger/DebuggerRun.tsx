import { useState } from "react";
import { useWorkflowRunQuery } from "@/routes/workflows/hooks/useWorkflowRunQuery";
import { DebuggerRunTimeline } from "./DebuggerRunTimeline";
import {
  ActionItem,
  WorkflowRunOverviewActiveElement,
} from "@/routes/workflows/workflowRun/WorkflowRunOverview";
import { ObserverThought, WorkflowRunBlock } from "../types/workflowRunTypes";
import { WorkflowRunBlockScreenshot } from "@/routes/workflows/workflowRun/WorkflowRunBlockScreenshot";
import { ObserverThoughtScreenshot } from "@/routes/workflows/workflowRun/ObserverThoughtScreenshot";
import { ActionScreenshot } from "@/routes/tasks/detail/ActionScreenshot";
import {
  isAction,
  isObserverThought,
  isWorkflowRunBlock,
} from "../types/workflowRunTypes";
import { AspectRatio } from "@/components/ui/aspect-ratio";

function DebuggerRun() {
  const { data: workflowRun } = useWorkflowRunQuery();
  const [activeItem, setActiveItem] =
    useState<WorkflowRunOverviewActiveElement>("stream");

  const handleBlockItemSelected = (block: WorkflowRunBlock) => {
    setActiveItem(block);
  };

  const handleActionItemSelected = (item: ActionItem) => {
    setActiveItem(item.action);
  };

  const handleObserverThoughtCardSelected = (thought: ObserverThought) => {
    setActiveItem(thought);
  };

  const workflowFailureReason = workflowRun?.failure_reason ? (
    <div
      className="align-self-start h-[8rem] min-h-[8rem] w-full overflow-y-auto rounded-md border border-red-600 p-4"
      style={{
        backgroundColor: "rgba(220, 38, 38, 0.10)",
        width: "calc(100% - 2rem)",
      }}
    >
      <div className="font-bold">Run Failure Reason</div>
      <div className="text-sm">{workflowRun.failure_reason}</div>
    </div>
  ) : null;

  // Render screenshot based on selected item
  const renderScreenshot = () => {
    if (activeItem === "stream" || activeItem === null) {
      return (
        <div className="flex h-full items-center justify-center bg-slate-elevation1 text-sm text-slate-400">
          Click on a block or action to view its screenshot
        </div>
      );
    }

    if (isWorkflowRunBlock(activeItem)) {
      return (
        <WorkflowRunBlockScreenshot
          workflowRunBlockId={activeItem.workflow_run_block_id}
        />
      );
    }

    if (isObserverThought(activeItem)) {
      return (
        <ObserverThoughtScreenshot observerThoughtId={activeItem.thought_id} />
      );
    }

    if (isAction(activeItem)) {
      return (
        <ActionScreenshot
          index={activeItem.action_order ?? 0}
          stepId={activeItem.step_id ?? ""}
        />
      );
    }

    return null;
  };

  return (
    <div className="flex h-full w-full flex-col items-center justify-start overflow-hidden overflow-y-auto">
      {workflowFailureReason}
      {/* Screenshot preview section */}
      <div className="w-full px-4 pt-4">
        <AspectRatio ratio={16 / 9}>{renderScreenshot()}</AspectRatio>
      </div>
      {/* Timeline section */}
      <div className="h-full w-full">
        <DebuggerRunTimeline
          activeItem={activeItem}
          onActionItemSelected={handleActionItemSelected}
          onBlockItemSelected={handleBlockItemSelected}
          onObserverThoughtCardSelected={handleObserverThoughtCardSelected}
        />
      </div>
    </div>
  );
}

export { DebuggerRun };
