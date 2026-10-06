import { initializeApp } from "firebase-admin/app";
import {
  DocumentSnapshot,
  FieldValue,
  getFirestore,
} from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { onSchedule } from "firebase-functions/v2/scheduler";

initializeApp();

const firestore = getFirestore();
const messaging = getMessaging();
const weekdayNumbers: Record<string, number> = {
  Monday: 1,
  Tuesday: 2,
  Wednesday: 3,
  Thursday: 4,
  Friday: 5,
  Saturday: 6,
  Sunday: 7,
};

function hasErrorCode(error: unknown): error is { code: string } {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    typeof error.code === "string"
  );
}

function currentLocalTime(timeZone: string, now: Date) {
  const values = new Map<string, string>(
    new Intl.DateTimeFormat("en-US", {
      timeZone,
      weekday: "long",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      hourCycle: "h23",
    })
      .formatToParts(now)
      .map((part): [string, string] => [part.type, part.value]),
  );
  const year = values.get("year");
  const month = values.get("month");
  const day = values.get("day");
  const hour = values.get("hour");
  const minute = values.get("minute");
  const weekday = values.get("weekday");

  if (!year || !month || !day || !hour || !minute || !weekday) {
    throw new Error(`Could not determine the local time for ${timeZone}.`);
  }

  return {
    date: `${year}-${month}-${day}`,
    hour: Number(hour) % 24,
    minute: Number(minute),
    weekday: weekdayNumbers[weekday],
  };
}

export const sendDueWaterReminders = onSchedule(
  {
    schedule: "every 1 minutes",
    timeZone: "UTC",
    maxInstances: 1,
    concurrency: 1,
    timeoutSeconds: 55,
  },
  async () => {
    const now = new Date();
    const reminders = await firestore
      .collectionGroup("waterReminders")
      .where("enabled", "==", true)
      .get();
    const userSnapshots = new Map<string, DocumentSnapshot>();

    for (const reminderDocument of reminders.docs) {
      const userReference = reminderDocument.ref.parent.parent;
      if (!userReference) continue;

      let userSnapshot = userSnapshots.get(userReference.path);
      if (!userSnapshot) {
        userSnapshot = await userReference.get();
        userSnapshots.set(userReference.path, userSnapshot);
      }

      const user = userSnapshot.data();
      if (
        !user ||
        user.notificationsEnabled !== true ||
        typeof user.pushToken !== "string" ||
        typeof user.timeZone !== "string"
      ) {
        continue;
      }

      const reminder = reminderDocument.data();
      const days = Array.isArray(reminder.days)
        ? reminder.days as string[]
        : [];
      let dueDate: string | undefined;
      for (let minutesLate = 0; minutesLate <= 5; minutesLate += 1) {
        const occurrence = currentLocalTime(
          user.timeZone,
          new Date(now.getTime() - minutesLate * 60_000),
        );
        if (
          days.some((day) => weekdayNumbers[day] === occurrence.weekday) &&
          reminder.hour === occurrence.hour &&
          reminder.minute === occurrence.minute &&
          reminder.lastSentDate !== occurrence.date
        ) {
          dueDate = occurrence.date;
          break;
        }
      }
      if (!dueDate) continue;

      try {
        await messaging.send({
          token: user.pushToken,
          notification: {
            title: "Water Intake Reminder",
            body:
              typeof reminder.message === "string" && reminder.message.trim()
                ? reminder.message.trim()
                : "Time to drink a fresh glass of water!",
          },
          webpush: {
            notification: {
              icon: "/icons/Icon-192.png",
            },
          },
        });
      } catch (error) {
        if (
          hasErrorCode(error) &&
          (error.code === "messaging/registration-token-not-registered" ||
            error.code === "messaging/invalid-registration-token")
        ) {
          await userReference.update({
            pushToken: FieldValue.delete(),
            notificationsEnabled: false,
          });
          continue;
        }
        throw error;
      }

      await reminderDocument.ref.update({
        lastSentDate: dueDate,
        lastSentAt: FieldValue.serverTimestamp(),
      });
    }
  },
);
