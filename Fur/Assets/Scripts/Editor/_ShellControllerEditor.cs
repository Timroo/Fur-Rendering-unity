using UnityEngine;
using UnityEditor;

[CustomEditor(typeof(_ShellController))]
public class _ShellControllerEditor : Editor
{
    public override void OnInspectorGUI()
    {
        DrawDefaultInspector();

        _ShellController shellController = (_ShellController)target;
        if (GUILayout.Button("更新Shell"))
        {
            shellController.UpdateShellEditor();
        }
        if (GUILayout.Button("删除Shell"))
        {
            shellController.ClearShellEditor();
        }
    }
}
